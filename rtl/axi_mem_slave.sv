`timescale 1ns / 1ps

module axi_mem_slave(
    input clk,
    input resetn,

    // write address channel
    input awvalid, // master is sending valid address
    input [3:0] awid, // unique id for each transaction (no effect in this project - 1 pipeline)
    input [3:0] awlen, // number of transactions per transfer = awlen + 1
    input [2:0] awsize, //number of bytes read/write per transaction (0 -> 1, 1 -> 2, 2 -> 4)
    input [31:0] awaddr, // address to write
  	input [1:0] awburst, // 3 address burst mode: Fix, increment, wrap
    output reg awready, // slave is ready to accept request (read/write)

    // write data channel
    input wvalid, // master is sending valid data
    input [3:0] wid, // unique id for each transaction (no effect in this project - 1 pipeline)
    input [31:0] wdata, // data that want to write into the address
    input [3:0] wstrb, // to determine the valid status for each lane of wdata (4bits -> 4 lane)
    input wlast, // notify the last transaction in the write burst
    output reg wready, // slave is ready to accept new data

    // write response channel
    input bready, // master is ready to accept response
    output reg bvalid, // slave return valid respnse
    output reg [3:0] bid, // unique id for each transaction (no effect in this project - 1 pipeline)
    output reg [1:0] bresp, // slave response to master request (0: Succesful, 10: SLVERR (awsize > 3), 11: no slave address)

   // read address channel 
    input arvalid, // master is sending valid address
    input [3:0] arid, // unique id for each transaction (no effect in this project - 1 pipeline)
    input [3:0] arlen, // number of transactions per transfer = awlen + 1
    input [2:0] arsize, //number of bytes read/write per transaction (0 -> 1, 1 -> 2, 2 -> 4)
    input [31:0] araddr, // address to read
  	input [1:0] arburst, // 3 address burst mode: Fix, increment, wrap
    output reg arready, // slave is ready to accept request (read/write)

  // read data + respone (share channel)
    output reg rvalid, // slave is sending valid data
    output reg [3:0] rid, //slave sengding unique id for each transaction (no effect in this project - 1 pipeline)
    output reg [31:0] rdata, // data return from reading from the address to master
    //output reg [3:0] rstrb, // to determine the valid status for each lane of wdata (4bits -> 4 lane)
    output reg rlast, // notify the last transaction in the read burst
    input rready, // master is ready to accept new data sned back from the slave
    output reg [1:0] rresp // slave response to master request (0: Succesful, 10: SLVERR (awsize > 3), 11: no slave address)
);


// 1. FSM for write address channel
  typedef enum bit [1:0] {awidle = 2'b00, awstart = 2'b01, awreadys = 2'b10} awstate_type;
  awstate_type awstate, awnext_state;
  typedef enum bit [2:0] {widle = 0, wstart = 1, wreadys = 2, wvalids = 3, waddr_dec = 4} wstate_type;
  wstate_type wstate, wnext_state;
  
  reg [31:0] awaddr_temp;
  
  // sequential current state logic
  always_ff@(posedge clk or negedge resetn)
    begin
      if (!resetn) begin
        awstate <= awidle;  ///idle state for write address FSM
      end else begin
        awstate <= awnext_state;
      end
    end
  
  
  // combinational next state logic
  always_comb
    begin
      case (awstate)
      awidle: begin
         awready  = 1'b0;
         awnext_state = awstart;  
      end
      
      awstart: begin
        if (awvalid) begin
          awnext_state = awreadys;
          awaddr_temp  = awaddr;  
        end else begin
          awnext_state = awstart;
        end
      end
      
      awreadys: begin
        awready = 1'b1;
        if (wstate == wreadys) begin // wait until the system finish updating the memory
        // wready = 1 means the slave finish updating the memory => current transaction is complete 
        //=> awready return to 0 and wait for the next transaction
        // if wready is not = 1 yet => stay in the current state
            awnext_state  = awidle;
        end else begin
            awnext_state =  awreadys;
        end
      end  
     endcase
    end

// 2. FSM for write data channel

  reg [31:0] wdata_temp;
  reg [7:0] mem[128] = '{default:0};
  // Clear memory whenever reset is asserted
  always @(negedge resetn) begin
      for (int i = 0; i < 128; i = i + 1) begin
          mem[i] = 8'h00;
      end
  end
  reg [31:0] return_addr;
  reg [31:0] next_addr;
  reg first; // indicate if the it this the first transaction of the transfer => addr = awaddr
  reg [7:0] boundary;  
  reg [3:0] wlen_count;
 
    // address calculation for fix burst type
  function bit[31:0] data_wr_fixed (input [3:0] wstrb, input [31:0] awaddr_temp);
    unique case (wstrb)
      4'b0001: begin 
        mem[awaddr_temp] = wdata_temp[7:0];
      end
      
      4'b0010: begin 
        mem[awaddr_temp] = wdata_temp[15:8];
      end
      
      4'b0011: begin 
        mem[awaddr_temp] = wdata_temp[7:0];
        mem[awaddr_temp + 1] = wdata_temp[15:8];
      end
      
      4'b0100: begin 
        mem[awaddr_temp] = wdata_temp[23:16];
      end
      
      4'b0101: begin 
        mem[awaddr_temp] = wdata_temp[7:0];
        mem[awaddr_temp + 1] = wdata_temp[23:16];
      end
  
      4'b0110: begin 
        mem[awaddr_temp] = wdata_temp[15:8];
        mem[awaddr_temp + 1] = wdata_temp[23:16];
      end
      
      4'b0111: begin 
        mem[awaddr_temp] = wdata_temp[7:0];
        mem[awaddr_temp + 1] = wdata_temp[15:8];
        mem[awaddr_temp + 2] = wdata_temp[23:16];
      end
      
      4'b1000: begin 
        mem[awaddr_temp] = wdata_temp[31:24];
      end
      
      4'b1001: begin 
        mem[awaddr_temp] = wdata_temp[7:0];
        mem[awaddr_temp + 1] = wdata_temp[31:24];
      end
      
      
      4'b1010: begin 
        mem[awaddr_temp] = wdata_temp[15:8];
        mem[awaddr_temp + 1] = wdata_temp[31:24];
      end
      
      
      4'b1011: begin 
        mem[awaddr_temp] = wdata_temp[7:0];
        mem[awaddr_temp + 1] = wdata_temp[15:8];
        mem[awaddr_temp + 2] = wdata_temp[31:24];
      end
      
      4'b1100: begin 
        mem[awaddr_temp] = wdata_temp[23:16];
        mem[awaddr_temp + 1] = wdata_temp[31:24];
      end

      4'b1101: begin 
        mem[awaddr_temp] = wdata_temp[7:0];
        mem[awaddr_temp + 1] = wdata_temp[23:16];
        mem[awaddr_temp + 2] = wdata_temp[31:24];
      end

      4'b1110: begin 
        mem[awaddr_temp] = wdata_temp[15:8];
        mem[awaddr_temp + 1] = wdata_temp[23:16];
        mem[awaddr_temp + 2] = wdata_temp[31:24];
      end
      
      4'b1111: begin
        mem[awaddr_temp] = wdata_temp[7:0];
        mem[awaddr_temp + 1] = wdata_temp[15:8];
        mem[awaddr_temp + 2] = wdata_temp[23:16];
        mem[awaddr_temp + 3] = wdata_temp[31:24];       
      end
    endcase
    return awaddr_temp;
  endfunction  
 
 
    
    // address calculation for the incr burst type
  function bit[31:0] data_wr_incr (input [3:0] wstrb, input [31:0] awaddr_temp);
      
      bit [31:0] addr; // return the address for the next transaction 
        //$display("DUT WRITE INCR: addr=%0d wstrb=%b wdata=%0h", 
          //awaddr_temp, wstrb, wdata_temp);
      unique case (wstrb)
      4'b0001: begin 
          mem[awaddr_temp] = wdata_temp[7:0];
          addr = awaddr_temp + 1;
      end
      
      4'b0010: begin 
          mem[awaddr_temp] = wdata_temp[15:8];
          addr = awaddr_temp + 1;
      end
      
      4'b0011: begin 
          mem[awaddr_temp] = wdata_temp[7:0];
          mem[awaddr_temp + 1] = wdata_temp[15:8];
          addr = awaddr_temp + 2;
      end
      
      4'b0100: begin 
          mem[awaddr_temp] = wdata_temp[23:16];
          addr = awaddr_temp + 1;
      end
      
      4'b0101: begin 
          mem[awaddr_temp] = wdata_temp[7:0];
          mem[awaddr_temp + 1] = wdata_temp[23:16];
          addr = awaddr_temp + 2;
      end
      
      4'b0110: begin 
          mem[awaddr_temp] = wdata_temp[15:8];
          mem[awaddr_temp + 1] = wdata_temp[23:16];
          addr = awaddr_temp + 2;
      end
      
      4'b0111: begin 
          mem[awaddr_temp] = wdata_temp[7:0];
          mem[awaddr_temp + 1] = wdata_temp[15:8];
          mem[awaddr_temp + 2] = wdata_temp[23:16];
          addr = awaddr_temp + 3;
      end
      
      4'b1000: begin 
          mem[awaddr_temp] = wdata_temp[31:24];
          addr = awaddr_temp + 1;
      end
      
      4'b1001: begin 
          mem[awaddr_temp] = wdata_temp[7:0];
          mem[awaddr_temp + 1] = wdata_temp[31:24];
          addr = awaddr_temp + 2;
      end
      
      4'b1010: begin 
          mem[awaddr_temp] = wdata_temp[15:8];
          mem[awaddr_temp + 1] = wdata_temp[31:24];
          addr = awaddr_temp + 2;
      end
      
      4'b1011: begin 
          mem[awaddr_temp] = wdata_temp[7:0];
          mem[awaddr_temp + 1] = wdata_temp[15:8];
          mem[awaddr_temp + 2] = wdata_temp[31:24];
          addr = awaddr_temp + 3;
      end
      
      4'b1100: begin 
          mem[awaddr_temp] = wdata_temp[23:16];
          mem[awaddr_temp + 1] = wdata_temp[31:24];
          addr = awaddr_temp + 2;
      end
  
      4'b1101: begin 
          mem[awaddr_temp] = wdata_temp[7:0];
          mem[awaddr_temp + 1] = wdata_temp[23:16];
          mem[awaddr_temp + 2] = wdata_temp[31:24];
          addr = awaddr_temp + 3;
      end
  
      4'b1110: begin 
          mem[awaddr_temp] = wdata_temp[15:8];
          mem[awaddr_temp + 1] = wdata_temp[23:16];
          mem[awaddr_temp + 2] = wdata_temp[31:24];
          addr = awaddr_temp + 3;
      end
      
      4'b1111: begin
          mem[awaddr_temp] = wdata_temp[7:0];
          mem[awaddr_temp + 1] = wdata_temp[15:8];
          mem[awaddr_temp + 2] = wdata_temp[23:16];
          mem[awaddr_temp + 3] = wdata_temp[31:24]; 
          addr = awaddr_temp + 4;      
      end
      endcase
    return addr;
  endfunction   
  
  
  // compute wrap_coundary for wrap burst type
  // wrap only available for awlen = 1, 3, 7, 15
  // boundary of a transfer = number of transactions/transfer * number of bytes/transaction
  // number of transaction/transfer = awlen + 1
  function bit [7:0] wrap_boundary (input bit [3:0] awlen, input bit[2:0] awsize);
    bit [7:0] boundary;
  
    unique case(awlen)
    4'b0001: begin
      unique case(awsize)
          3'b000: begin
            boundary = 2 * 1; 
          end
          3'b001: begin
            boundary = 2 * 2;																		
          end	
          3'b010: begin
            boundary = 2 * 4;																		
          end
      endcase
    end

    4'b0011: begin
      unique case(awsize)
        3'b000: begin
          boundary = 4 * 1; 
        end
        3'b001: begin
          boundary = 4 * 2;																		
        end	
        3'b010: begin
          boundary = 4 * 4;																		
        end
      endcase
    end
    
    4'b0111: begin
      unique case(awsize)
        3'b000: begin
          boundary = 8 * 1; 
        end
        3'b001: begin
          boundary = 8 * 2;																		
        end	
        3'b010: begin
          boundary = 8 * 4;																		
        end
      endcase 
    end

    4'b1111: begin
      unique case(awsize)
        3'b000: begin
          boundary = 16 * 1; 
        end
        3'b001: begin
          boundary = 16 * 2;																		
        end	
        3'b010: begin
          boundary = 16 * 4;																		
        end
      endcase
    end
    
    endcase
    return boundary;
  endfunction
  
  // address calculation for address wrap burst type
  function bit[31:0] data_wr_wrap (input [3:0] wstrb, input [31:0] awaddr_temp, input [7:0] wboundary);
      
    bit [31:0] addr1, addr2, addr3, addr4;
    bit [31:0] next_addr, next_addr2;
   
    unique case (wstrb)
    
      4'b0001: begin 
        mem[awaddr_temp] = wdata_temp[7:0];
        
        if ((awaddr_temp + 1) % wboundary == 0)
          addr1 = (awaddr_temp + 1) - wboundary;
        else
          addr1 = awaddr_temp + 1;
          
      return addr1;      
      end
      
      4'b0010: begin 
        mem[awaddr_temp] = wdata_temp[15:8];
        
       if((awaddr_temp + 1) % wboundary == 0)
          addr1 = (awaddr_temp + 1) - wboundary;
        else
          addr1 = awaddr_temp + 1;
           
      return addr1;   
      end
    
      4'b0011: begin 
        mem[awaddr_temp] = wdata_temp[7:0];
        
       if ((awaddr_temp + 1) % wboundary == 0)
          addr1 = (awaddr_temp + 1) - wboundary;
        else
          addr1 = awaddr_temp + 1;
                  
       mem[addr1] = wdata_temp[15:8]; 
              
       if ((addr1 + 1) % wboundary == 0)
          addr2 = (addr1 + 1) - wboundary;
        else
          addr2 = addr1 + 1;
           
        return addr2;   
       end 
      
      4'b0100: begin 
        mem[awaddr_temp] = wdata_temp[23:16];
         
        if ((awaddr_temp + 1) % wboundary == 0)
          addr1 = (awaddr_temp + 1) - wboundary;
        else
          addr1 = awaddr_temp + 1;
           
       return addr1;
      end
      
      4'b0101: begin 
        mem[awaddr_temp] = wdata_temp[7:0];
        
        if ((awaddr_temp + 1) % wboundary == 0)
          addr1 = (awaddr_temp + 1) - wboundary;
        else
          addr1 = awaddr_temp + 1;
      
        mem[addr1] = wdata_temp[23:16];
      
        if ((addr1 + 1) % wboundary == 0)
          addr2 = (addr1 + 1) - wboundary;
        else
          addr2 = addr1 + 1;
           
        return addr2;    
      end
    
      
      4'b0110: begin 
        mem[awaddr_temp] = wdata_temp[15:8];
        
        if ((awaddr_temp + 1) % wboundary == 0)
          addr1 = (awaddr_temp + 1) - wboundary;
        else
          addr1 = awaddr_temp + 1;
        
        mem[addr1] = wdata_temp[23:16];
         
        if ((addr1 + 1) % wboundary == 0)
          addr2 = (addr1 + 1) - wboundary;
        else
          addr2 = addr1 + 1;
          
        return addr2;  
      end

      4'b0111: begin 
        mem[awaddr_temp] = wdata_temp[7:0];    
        if ((awaddr_temp + 1) % wboundary == 0)
          addr1 = (awaddr_temp + 1) - wboundary;
        else
          addr1 = awaddr_temp + 1;
          
        mem[addr1] = wdata_temp[15:8];
         
        if ((addr1 + 1) % wboundary == 0)
          addr2 = (addr1 + 1) - wboundary;
        else
          addr2 = addr1 + 1;
           
        mem[addr2] = wdata_temp[23:16];
         
        if ((addr2 + 1) % wboundary == 0)
          addr3 = (addr2 + 1) - wboundary;
        else
          addr3 = addr2 + 1;
          
        return addr3;
     end
      
      4'b1000: begin 
        mem[awaddr_temp] = wdata_temp[31:24];
         
        if ((awaddr_temp + 1) % wboundary == 0)
          addr1 = (awaddr_temp + 1) - wboundary;
        else
          addr1 = awaddr_temp + 1;
           
        return addr1;
      end
      
      4'b1001: begin 
        mem[awaddr_temp] = wdata_temp[7:0];
         
        if ((awaddr_temp + 1) % wboundary == 0)
          addr1 = (awaddr_temp + 1) - wboundary;
        else
          addr1 = awaddr_temp + 1;
    
      mem[addr1] = wdata_temp[31:24];
    
      if ((addr1 + 1) % wboundary == 0)
        addr2 = (addr1 + 1) - wboundary;
      else
        addr2 = addr1 + 1;
         
        return addr2;
      end
      
      
      4'b1010: begin 
        mem[awaddr_temp] = wdata_temp[15:8];
         
        if ((awaddr_temp + 1) % wboundary == 0)
          addr1 = (awaddr_temp + 1) - wboundary;
        else
          addr1 = awaddr_temp + 1;
         
        mem[addr1] = wdata_temp[31:24];
         
        if ((addr1 + 1) % wboundary == 0)
          addr2 = (addr1 + 1) - wboundary;
        else
          addr2 = addr1 + 1;
        return addr2;
      end
      
      4'b1011: begin 
        mem[awaddr_temp] = wdata_temp[7:0];
         
        if ((awaddr_temp + 1) % wboundary == 0)
          addr1 = (awaddr_temp + 1) - wboundary;
        else
          addr1 = awaddr_temp + 1;
        
        mem[addr1] = wdata_temp[15:8];
         
        if ((addr1 + 1) % wboundary == 0)
          addr2 = (addr1 + 1) - wboundary;
        else
          addr2 = addr1 + 1;
           
        mem[addr2] = wdata_temp[31:24];
         
        if ((addr2 + 1) % wboundary == 0)
          addr3 = (addr2 + 1) - wboundary;
        else
          addr3 = addr2 + 1;
                
      return addr3;
      end
      
      4'b1100: begin 
        mem[awaddr_temp] = wdata_temp[23:16];
         
        if((awaddr_temp + 1) % wboundary == 0)
          addr1 = (awaddr_temp + 1) - wboundary;
        else
          addr1 = awaddr_temp + 1;
         
        mem[addr1] = wdata_temp[31:24];
         
        if ((addr1 + 1) % wboundary == 0)
          addr2 = (addr1 + 1) - wboundary;
        else
          addr2 = addr1 + 1;
        return addr2;
      end
 
      4'b1101: begin 
        mem[awaddr_temp] = wdata_temp[7:0];
        
        if ((awaddr_temp + 1) % wboundary == 0)
          addr1 = (awaddr_temp + 1) - wboundary;
        else
          addr1 = awaddr_temp + 1;

        mem[addr1] = wdata_temp[23:16];
        
        if ((addr1 + 1) % wboundary == 0)
          addr2 = (addr1 + 1) - wboundary;
        else
          addr2 = addr1 + 1;

        mem[addr2] = wdata_temp[31:24];
        
        if ((addr2 + 1) % wboundary == 0)
          addr3 = (addr2 + 1) - wboundary;
        else
          addr3 = addr2 + 1;          
       return addr3;
      end
 
      4'b1110: begin 
        mem[awaddr_temp] = wdata_temp[15:8];
        
        if ((awaddr_temp + 1) % wboundary == 0)
          addr1 = (awaddr_temp + 1) - wboundary;
        else
          addr1 = awaddr_temp + 1;
        
        mem[addr1] = wdata_temp[23:16];
        
        if ((addr1 + 1) % wboundary == 0)
          addr2 = (addr1 + 1) - wboundary;
        else
          addr2 = addr1 + 1;
        
        mem[addr2] = wdata_temp[31:24];
        
        if ((addr2 + 1) % wboundary == 0)
          addr3 = (addr2 + 1) - wboundary;
        else
          addr3 = addr2 + 1;
           
        return addr3;
      end
      
      4'b1111: begin
        mem[awaddr_temp] = wdata_temp[7:0];
           
        if ((awaddr_temp + 1) % wboundary == 0)
          addr1 = (awaddr_temp + 1) - wboundary;
        else
          addr1 = awaddr_temp + 1;

        mem[addr1] = wdata_temp[15:8];
        
        if ((addr1 + 1) % wboundary == 0)
          addr2 = (addr1 + 1) - wboundary;
        else
          addr2 = addr1 + 1;
        
        mem[addr2] = wdata_temp[23:16];
      
        if ((addr2 + 1) % wboundary == 0)
          addr3 = (addr2 + 1) - wboundary;
        else
          addr3 = addr2 + 1;
      
        mem[addr3] = wdata_temp[31:24]; 
        
        if ((addr3 + 1) % wboundary == 0)
          addr4 = (addr3 + 1) - wboundary;
        else
          addr4 = addr3 + 1;
           
        return addr4;        
      end
    endcase
  endfunction   
  
  
  // state type for write data channel fsm
  // sequential current state logic
  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
        wstate <= widle;  
    end else begin
        wstate <= wnext_state;
    end
  end
  
  
  always_comb begin
    case (wstate)
      
      widle: begin
        wready = 1'b0;
        wnext_state = wstart; 
        first = 1'b0; 
        wlen_count = 0;
      end
      
      wstart: begin
        if (wvalid) begin
          wnext_state = waddr_dec;
          wdata_temp  = wdata;
        end else begin
          wnext_state = wstart;
        end 
      end
      
      waddr_dec: begin // this state purpose is to determine (decode) which is the next address for  transaction
            
        if (first == 0) begin // check if is this a first transaction or not  
          next_addr  = awaddr;
          first = 1'b1;
          wlen_count = 0;
        end else if (wlen_count < (awlen + 1 )) begin
          next_addr = return_addr;      
        end else begin
          next_addr  = awaddr;
        end

        wnext_state = wreadys;
        
      end  
      
      wreadys: begin

        if (wlast == 1'b1) begin
            wnext_state = widle;
            wready      = 1'b0;
            wlen_count  = 0;
            first       = 0;
        end else if (wlen_count < (awlen + 1)) begin
            wnext_state = wvalids;
            wready      = 1'b1;
        end else begin
            wnext_state = wreadys;
        end

        case (awburst)

            2'b00: begin
                return_addr = data_wr_fixed(wstrb, awaddr);
            end

            2'b01: begin
                return_addr = data_wr_incr(wstrb, next_addr);
            end

            2'b10: begin
                boundary    = wrap_boundary(awlen, awsize);
                return_addr = data_wr_wrap(wstrb, next_addr, boundary);
            end

        endcase
      end
          
          
      wvalids: begin    
        wready      = 1'b0;
        wnext_state = wstart;
       
        if (wlen_count < (awlen + 1)) begin
          wlen_count = wlen_count + 1;
        end else begin
          wlen_count = wlen_count;
        end
      end
    endcase    
 end

// 3. FSM for write response channel
  typedef enum bit [1:0] {bidle = 0, bdetect_last = 1, bstart = 2, bwait = 3} bstate_type;
  bstate_type bstate, bnext_state;
  
  // sequential current state logic
  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      bstate <= bidle;  
    end else begin
      bstate <= bnext_state;
    end
  end
 
 
  always_comb begin
    case (bstate)

      bidle: begin 
          bid = 1'b0;
          bresp = 1'b0; 
          bvalid = 1'b0;
          bnext_state = bdetect_last; 
      end
      
      bdetect_last: begin
          if (wlast) begin
            bnext_state = bstart;
          end else begin
            bnext_state = bdetect_last; 
          end
      end
      
      bstart: begin
        bid = awid;
        bvalid = 1'b1;
        bnext_state = bwait;
        if ((awaddr < 128 ) && (awsize <= 3'b010)) begin
          bresp = 2'b00;  ///okay
        end else if (awsize > 3'b010) begin
          bresp = 2'b10; /////slverr
        end else begin
          bresp = 2'b11;  ///no slave address
        end  
      end
    
    bwait: begin
      if (bready == 1'b1) begin
        bnext_state = bidle;
      end else begin
        bnext_state = bwait;
      end
    end

    endcase
  end

  // 4. FSM for read adress
  typedef enum bit [1:0] {aridle = 0, arstart = 1, arreadys = 2} arstate_type;
  arstate_type arstate, arnext_state;
  always_ff @(posedge clk, negedge resetn) begin
    if (!resetn) begin
      arstate <= aridle;
    end else begin
      arstate <= arnext_state;
    end
 end
 
 
  reg [31:0] araddrt;
 
  always_comb begin 
    case (arstate)
      aridle: begin
        arready = 1'b0;
        arnext_state = arstart;
      end
    
      arstart: begin
        if (arvalid == 1'b1 && !rlast) begin
          arnext_state = arreadys;
          araddrt = araddr; 
        end else begin
          arnext_state = arstart;
        end   
      end
    
      arreadys: begin
        arnext_state = aridle;
        arready = 1'b1;
      end
    endcase
  end

  function void read_data_fixed (input [31:0] addr, input [2:0] arsize);
    unique case(arsize)
      3'b000: begin
        rdata[7:0] = mem[addr];    
      end
        
      3'b001: begin
        rdata[7:0]  = mem[addr]; 
        rdata[15:8] = mem[addr + 1]; 
      end 
      
      3'b010: begin
        rdata[7:0]    = mem[addr]; 
        rdata[15:8]   = mem[addr + 1]; 
        rdata[23:16]  = mem[addr + 2]; 
        rdata[31:24]  = mem[addr + 3]; 
      end
    endcase       
  endfunction
  

  function bit [31:0] read_data_incr (input [31:0] addr, input [2:0] arsize);
    bit [31:0] nextaddr;
      
    unique case(arsize)
      3'b000: begin
        rdata[7:0] = mem[addr];
        nextaddr = addr + 1;
      end
      
      3'b001: begin
        rdata[7:0]  = mem[addr];
        rdata[15:8] = mem[addr + 1];
        nextaddr = addr + 2;  
      end
      
      3'b010: begin
        rdata[7:0]    = mem[addr];
        rdata[15:8]   = mem[addr + 1];
        rdata[23:16]  = mem[addr + 2];
        rdata[31:24]  = mem[addr + 3];
        nextaddr = addr + 4;  
      end
    
    endcase

    return nextaddr;
  endfunction


  function bit [31:0] read_data_wrap (input bit [31:0] addr, input bit [2:0] rsize, input [7:0] rboundary);
    
    bit [31:0] addr1,addr2,addr3,addr4;
    
    unique case (rsize)
        3'b000: begin
          rdata[7:0] = mem[addr];
          
          if (((addr + 1) % rboundary ) == 0) begin
            addr1 = (addr + 1) - rboundary;
          end else begin
            addr1 = (addr + 1);
          end
                
          return addr1;       
      end
      
      3'b001: begin
          rdata[7:0] = mem[addr];
          
          if (((addr + 1) % rboundary ) == 0) begin
            addr1 = (addr + 1) - rboundary;
          end else begin
            addr1 = (addr + 1);
          end
                
          rdata[15:8] = mem[addr1];
          
          if (((addr1 + 1) % rboundary ) == 0) begin
            addr2 = (addr1 + 1) - rboundary;
          end else begin
            addr2 = (addr1 + 1);
          end         
                
          return addr2;       
      end
      
      3'b010: begin
      
        rdata[7:0] = mem[addr];
          
        if (((addr + 1) % rboundary ) == 0) begin
          addr1 = (addr + 1) - rboundary;
        end else begin
          addr1 = (addr + 1);
        end 
                
        rdata[15:8] = mem[addr1];
          
        if (((addr1 + 1) % rboundary ) == 0) begin
          addr2 = (addr1 + 1) - rboundary;
        end else begin
          addr2 = (addr1 + 1);
        end  
                
        rdata[23:16]  = mem[addr2];
            
        if (((addr2 + 1) % rboundary ) == 0) begin
          addr3 = (addr2 + 1) - rboundary;
        end else begin
          addr3 = (addr2 + 1); 
        end
            
        rdata[31:24] = mem[addr3];
            
        if (((addr3 + 1) % rboundary ) == 0) begin
          addr4 = (addr3 + 1) - rboundary;
        end else begin
          addr4 = (addr3 + 1);  
        end          
        
        return addr4;
      end  
    endcase
  endfunction

  // 5. FSM for read data channel + response
  reg rdfirst;
  bit [31:0] rdnextaddr, rdretaddr;
  reg [3:0] len_count;
  reg [7:0] rdboundary;
 
  typedef enum bit [2:0] {ridle = 0, rstart = 1, rwait = 2, rvalids = 3, rerror = 4} rstate_type;
  rstate_type rstate, rnext_state;

  always_ff @(posedge clk, negedge resetn) begin
    if (!resetn) begin
      rstate  <= ridle;
    end else begin
      rstate  <= rnext_state;
    end
 end
 
  always_comb begin
    case (rstate)
      ridle: begin

        rid = 0;
        rdfirst = 0;
        rdata = 0;
        rresp = 0;
        rlast = 0;
        rvalid = 0;
        len_count = 0;
        
        if (arvalid) begin
          rnext_state = rstart;
        end else begin
          rnext_state = ridle; 
        end
      end
    
      rstart: begin
        if ((araddrt < 128) && (arsize <= 3'b010) ) begin
          rid = arid;
          rvalid = 1'b1;
          rnext_state = rwait;
          rresp = 2'b00;

          unique case(arburst)
          
            2'b00: begin // fixed address burst type
              if(rdfirst == 0) begin
                rdnextaddr  = araddr;
                rdfirst = 1'b1;
                len_count = 0;
              end else if (len_count != (arlen + 1)) begin
                rdnextaddr  = araddr;
              end
        
              read_data_fixed(araddrt, arsize);
              end

            2'b01: begin
              if(rdfirst == 0) begin
                rdnextaddr  = araddr;
                rdfirst = 1'b1;
                len_count = 0;
              end else if (len_count != (arlen + 1)) begin
                rdnextaddr = rdretaddr;
              end   
                              
              rdretaddr = read_data_incr(rdnextaddr, arsize); 
            end

            2'b10: begin
              if (rdfirst == 0) begin
                rdnextaddr  = araddr;
                rdfirst = 1'b1;
                len_count = 0;
              end else if (len_count != (arlen + 1)) begin
                rdnextaddr = rdretaddr;    
              end   

              rdboundary = wrap_boundary(arlen, arsize);
              rdretaddr  = read_data_wrap(rdnextaddr, arsize, rdboundary);
            end
          endcase
        
        end else if ( (araddr >= 128) && ( arsize <= 3'b010) ) begin 
          rresp = 2'b11;  
          rvalid = 1'b1;
          rnext_state = rerror; 
        end else if (arsize > 3'b010) begin
          rresp = 2'b10;
          rvalid = 1'b1;
          rnext_state = rerror;
        end  
      end
    
      rwait: begin
          rvalid = 1'b0;
          if (rready == 1'b1) begin
            rnext_state = rvalids; 
          end else begin
            rnext_state = rwait;
          end
      end
    
      rvalids: begin
        len_count = len_count + 1;
        if (len_count == (arlen + 1)) begin
          rnext_state = ridle;
          rlast       = 1'b1;
        end else begin
          rnext_state = rstart;
          rlast       = 1'b0;
        end 
      end
    
      rerror : begin 
          rvalid = 1'b0;

          if (len_count < (arlen)) begin
            if (arready) begin
              rnext_state = rstart;
              len_count = len_count + 1;
            end
          end else begin
              rlast = 1'b1; 
              rnext_state = ridle;
              len_count   = 0;
          end 
        end 
      
      default : rnext_state = ridle;
    endcase  
  end
endmodule



interface axi_if();
  
  logic awvalid;   
  logic awready; 
  logic [3:0] awid; 
  logic [3:0] awlen; 
  logic [2:0] awsize; 
  logic [31:0] awaddr; 
  logic [1:0] awburst; 
  
  
  logic wvalid; 
  logic wready; 
  logic [3:0] wid; 
  logic [31:0] wdata; 
  logic [3:0] wstrb; 
  logic wlast; 
  
  logic bready; 
  logic bvalid; 
  logic [3:0] bid; 
  logic [1:0] bresp; 
  
  logic arvalid;  
  logic arready;  
  logic [3:0] arid; 
  logic [3:0] arlen; 
  logic [2:0] arsize; 
  logic [31:0] araddr; 
  logic [1:0] arburst; 
  
  logic rvalid; 
  logic rready;  
  logic [3:0] rid; 
  logic [31:0] rdata; 
  logic [3:0] rstrb; 
  logic rlast; 
  logic [1:0] rresp; 
  
  logic clk;
  logic resetn;
 
endinterface // Code your design here

