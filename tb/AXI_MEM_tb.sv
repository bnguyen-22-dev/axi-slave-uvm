`timescale 1ns / 1ps

`include "uvm_macros.svh"
import uvm_pkg::*;


class AXI_mem_config extends uvm_object;
    `uvm_object_utils(AXI_mem_config)

    function new(string path = "AXI_mem_config");
        super.new(path);
    endfunction

    uvm_active_passive_enum agent_type = UVM_ACTIVE;
endclass

typedef enum bit [1:0] {AXI_READ = 0, AXI_WRITE = 1, AXI_RESET = 2} axi_slave_operation_e;


class transaction extends uvm_sequence_item;
    `uvm_object_utils(transaction)

    function new(string path = "axi_transaction");
        super.new(path);
    endfunction

    rand axi_slave_operation_e op_mode;
    rand bit [3:0] id; // transaction id
    rand bit [31:0] addr;
    rand bit [3:0] len; // number of transaction per transfer = len + 1
    rand bit [2:0] size; // number of bytes/ transaction: 0 -> 1 byte, 1 -> 2 byte, 2-> 4 byte
    rand bit [1:0] burst; // 3 burst mode: 0 -> fixed, 1 -> incr, 2 -> wrap

    rand bit [31:0] data_q[$];
    rand bit [3:0] strb[$];

    bit [1:0] resp;   // store bresp rresp

    constraint c_size {
      size inside {[0:2]};
    }

    constraint c_burst {
      burst inside {[0:2]};
    }

    constraint c_addr {
        if (burst == 2'b01) { // INCR burst
            addr + ((len + 1) * (1 << size)) <= 128;
        }
        else {
            addr < 128;
        }
    }

    constraint c_data {
        foreach (data_q[i])
            data_q[i] inside {[0:1024]};
    }
	
  /*
  constraint c_data_q {
    unique {data_q};
  }
  */

    constraint c_queue_size{
        if (op_mode == AXI_WRITE) {
            data_q.size() == len + 1;
            strb.size() == len + 1;
        } else {
            data_q.size() == 0;
            strb.size() == 0;
        }
    }

    constraint c_strb { // exclude the 0000 case
        foreach (strb[i]) {
            strb[i] inside {[4'b0001:4'b1111]};
        }
    }

    constraint c_wrap_len {
        if (burst == 2'b10) 
            len inside {4'd1, 4'd3, 4'd7, 4'd15};
    }

endclass

// 1. reset_test
class reset_test_seq extends uvm_sequence #(transaction);
    `uvm_object_utils(reset_test_seq)

    function new(string path = "reset_test_seq");
        super.new(path);
    endfunction
    
    transaction tr;

    virtual task body();
        tr = transaction::type_id::create("tr");
        start_item(tr);
        assert(tr.randomize());
        tr.op_mode = AXI_RESET;
        finish_item(tr);
    endtask
endclass

// 2. single write test
class single_write_test_seq extends uvm_sequence #(transaction);
    `uvm_object_utils(single_write_test_seq)

    function new(string path = "single_write_test_seq");
        super.new(path);
    endfunction
    
    transaction tr;

    virtual task body();
        tr = transaction::type_id::create("tr");
        start_item(tr);
        assert(tr.randomize() with {
            op_mode == AXI_WRITE;
            len == 0; // single write in a transfer
            size == 2; // sending 4 bytes
            burst == 0; // fixed mode
            //randomize data
            //randomize address
          strb[0] == 4'b1111;
        });
        finish_item(tr);
    endtask
endclass

// 3. single_read_test
class single_read_test_seq extends uvm_sequence #(transaction);
    `uvm_object_utils(single_read_test_seq)

    function new(string path = "single_read_test_seq");
        super.new(path);
    endfunction
    
    transaction tr;

    virtual task body();
        tr = transaction::type_id::create("tr");
        start_item(tr);
        assert(tr.randomize() with {
            op_mode == AXI_READ;
            len == 0; // single read in a transfer
            size == 2; // sending 4 bytes
            burst == 0; // fixed mode
            //randomize data
            //randomize address
            //strb not use in read mode 
        });
        finish_item(tr);
    endtask
endclass

//4. write_read_test
class write_read_test_seq extends uvm_sequence #(transaction);
    `uvm_object_utils(write_read_test_seq)

    function new(string path = "write_read_test_seq");
        super.new(path);
    endfunction
    
    transaction tr_wr;
    transaction tr_rd;


    virtual task body();
        tr_wr = transaction::type_id::create("tr_wr");
        start_item(tr_wr);
        assert(tr_wr.randomize() with {
            op_mode == AXI_WRITE;
            len == 0; // single write in a transfer
            size == 2; // sending 4 bytes
            burst == 0; // fixed mode
            //randomize data
            //randomize address
          strb[0] == 4'b1111;
        });
        finish_item(tr_wr);

        tr_rd = transaction::type_id::create("tr_rd");
        start_item(tr_rd);
      assert(tr_rd.randomize() with {
            op_mode == AXI_READ;
            len == tr_wr.len; // single read in a transfer
            size == tr_wr.size; // sending 4 bytes
            burst == tr_wr.burst; // fixed mode
            addr == tr_wr.addr;
            //strb not use in read mode 
        });
        finish_item(tr_rd);
    endtask
endclass

// 5. fixed_burst_write_read_test
class fixed_burst_write_read_test_seq extends uvm_sequence #(transaction);
    `uvm_object_utils(fixed_burst_write_read_test_seq)

    function new(string path = "fixed_burst_write_read_test_seq");
        super.new(path);
    endfunction

    transaction tr_wr;
    transaction tr_rd;


    virtual task body();
        tr_wr = transaction::type_id::create("tr_wr");
        start_item(tr_wr);
        assert(tr_wr.randomize() with {
            op_mode == AXI_WRITE;
            len > 0; // burst test, len > 0
            size == 2; // sending 4 bytes
            burst == 0; // fixed mode
            //randomize data
            //randomize address
        });
        foreach (tr_wr.strb[i]) begin
            tr_wr.strb[i] = 4'b1111;
        end
        finish_item(tr_wr);

        tr_rd = transaction::type_id::create("tr_rd");
        start_item(tr_rd);
      assert(tr_rd.randomize() with {
            op_mode == AXI_READ;
            len == tr_wr.len; // single read in a transfer
            size == tr_wr.size; // sending 4 bytes
            burst == tr_wr.burst; // fixed mode
            addr == tr_wr.addr;
            //strb not use in read mode 
        });
        finish_item(tr_rd);
    endtask
    
endclass

// 6. incr_burst_write_read_test
class incr_burst_write_read_test_seq extends uvm_sequence #(transaction);
    `uvm_object_utils(incr_burst_write_read_test_seq)

    function new(string path = "incr_burst_write_read_test_seq");
        super.new(path);
    endfunction

    transaction tr_wr;
    transaction tr_rd;

    virtual task body();
        tr_wr = transaction::type_id::create("tr_wr");
        start_item(tr_wr);
        assert(tr_wr.randomize() with {
            op_mode == AXI_WRITE;
            len > 0; // burst test, len > 0
            size == 2; // sending 4 bytes
            burst == 1; // incr mode
            //randomize data
            //randomize address
        });
        foreach (tr_wr.strb[i]) begin
            tr_wr.strb[i] = 4'b1111;
        end
        finish_item(tr_wr);

        tr_rd = transaction::type_id::create("tr_rd");
        start_item(tr_rd);
      assert(tr_rd.randomize() with {
            op_mode == AXI_READ;
            len == tr_wr.len; // single read in a transfer
            size == tr_wr.size; // sending 4 bytes
            burst == tr_wr.burst; // fixed mode
            addr == tr_wr.addr;
            //strb not use in read mode 
        });
        finish_item(tr_rd);
    endtask
    
endclass

//7. wrap_burst_write_read_test
class wrap_burst_write_read_test_seq extends uvm_sequence #(transaction);
    `uvm_object_utils(wrap_burst_write_read_test_seq)

    function new(string path = "wrap_burst_write_read_test_seq");
        super.new(path);
    endfunction
    
    transaction tr_wr;
    transaction tr_rd;

    virtual task body();
        tr_wr = transaction::type_id::create("tr_wr");
        start_item(tr_wr);
        assert(tr_wr.randomize() with {
            op_mode == AXI_WRITE;
            len > 0; // burst test, len > 0
            size == 2; // sending 4 bytes
            burst == 2; // wrap mode
            //randomize data
            //randomize address
        });
        foreach (tr_wr.strb[i]) begin
            tr_wr.strb[i] = 4'b1111;
        end
        finish_item(tr_wr);

        tr_rd = transaction::type_id::create("tr_rd");
        start_item(tr_rd);
      assert(tr_rd.randomize() with {
            op_mode == AXI_READ;
            len == tr_wr.len; // single read in a transfer
            size == tr_wr.size; // sending 4 bytes
            burst == tr_wr.burst; // fixed mode
            addr == tr_wr.addr;
            //strb not use in read mode 
        });
        finish_item(tr_rd);
    endtask

endclass

// 8. class transfer_size_test 
class transfer_size_test_seq extends uvm_sequence #(transaction);
    `uvm_object_utils(transfer_size_test_seq)

    function new(string path = "transfer_size_test_seq");
        super.new(path);
    endfunction
    
    transaction tr_wr;
    transaction tr_rd;

    virtual task body();
        for (int s = 0; s <= 2; s++) begin
            tr_wr = transaction::type_id::create("tr_wr");
            start_item(tr_wr);
            assert(tr_wr.randomize() with {
                op_mode == AXI_WRITE;
                len > 0; // burst test, len > 0
                size == s; // sending 4 bytes
                burst == 1; // incr mode
                //randomize data
                //randomize address
            });
                
            foreach (tr_wr.strb[i]) begin
                if (s == 0) 
                    tr_wr.strb[i] = 4'b0001;
                else if (s == 1) 
                    tr_wr.strb[i] = 4'b0011;
                else 
                    tr_wr.strb[i] = 4'b1111;
            end
              
            finish_item(tr_wr);
       

            tr_rd = transaction::type_id::create("tr_rd");
            start_item(tr_rd);
              assert(tr_rd.randomize() with {
                op_mode == AXI_READ;
                len == tr_wr.len; // single read in a transfer
                size == tr_wr.size; // sending 4 bytes
                burst == tr_wr.burst; // fixed mode
                addr == tr_wr.addr;
                //strb not use in read mode 
            });
              
            finish_item(tr_rd);
        end
    endtask
endclass
//9. burst_length_test

class burst_length_test_seq extends uvm_sequence #(transaction);
    `uvm_object_utils(burst_length_test_seq)

    function new(string path = "burst_length_test_seq");
        super.new(path);
    endfunction

    transaction tr_wr;
    transaction tr_rd;

    int burst_length[$] = '{0, 1, 3, 7, 15};

    virtual task body();
        foreach (burst_length[i]) begin
            tr_wr = transaction::type_id::create("tr_wr");
            start_item(tr_wr);
            assert(tr_wr.randomize() with {
                op_mode == AXI_WRITE;
                len == burst_length[i]; // burst test, len > 0
                size == 2; // sending 4 bytes
                burst == 1; // incr mode
                //randomize data
                //randomize address
        });
             foreach (tr_wr.strb[i]) begin
                tr_wr.strb[i] = 4'b1111;
            end
            
            finish_item(tr_wr);

            tr_rd = transaction::type_id::create("tr_rd");
            start_item(tr_rd);
          assert(tr_rd.randomize() with {
                op_mode == AXI_READ;
                len == tr_wr.len; // single read in a transfer
                size == tr_wr.size; // sending 4 bytes
                burst == tr_wr.burst; // fixed mode
                addr == tr_wr.addr;
                //strb not use in read mode 
            });
            finish_item(tr_rd);
        end
    endtask
endclass


// 10. partial strobe test
class partial_strobe_test_seq extends uvm_sequence #(transaction);
    `uvm_object_utils(partial_strobe_test_seq)

    function new(string path = "partial_strobe_test_seq");
        super.new(path);
    endfunction

    transaction tr_wr;
    transaction tr_rd;

    bit [3:0] strobe_list[$] = '{
        4'b0001,
        4'b0010,
        4'b0100,
        4'b1000,
        4'b0011,
        4'b1100,
        4'b0101,
        4'b1010,
        4'b1111
    };

    virtual task body();

        foreach (strobe_list[i]) begin

            tr_wr = transaction::type_id::create("tr_wr");

            start_item(tr_wr);
            assert(tr_wr.randomize() with {
                op_mode == AXI_WRITE;
                len     == 0;
                size    == 2;
                burst   == 1;      // INCR
                strb[0] == strobe_list[i];
            });
            finish_item(tr_wr);


            tr_rd = transaction::type_id::create("tr_rd");

            start_item(tr_rd);
            assert(tr_rd.randomize() with {
                op_mode == AXI_READ;
                addr    == tr_wr.addr;
                len     == tr_wr.len;
                size    == tr_wr.size;
                burst   == tr_wr.burst;
            });
            finish_item(tr_rd);
        end
    endtask

endclass

// 11. invalid_write_addr_test
class invalid_write_addr_test_seq extends uvm_sequence #(transaction);
    `uvm_object_utils(invalid_write_addr_test_seq)

    function new(string path = "invalid_write_addr_test_seq");
        super.new(path);
    endfunction

    transaction tr_wr;

    virtual task body();
        tr_wr = transaction::type_id::create("tr_wr");

        start_item(tr_wr);
        tr_wr.c_addr.constraint_mode(0);
        assert(tr_wr.randomize() with {
            op_mode == AXI_WRITE;
            len     == 0;
            size    == 2;
            burst   == 1;      // INCR
            strb[0] == 4'b1111;
            addr > 128;
        });
        finish_item(tr_wr);
    endtask
endclass

// 12. invalid_read_size_test
class invalid_read_addr_test_seq extends uvm_sequence #(transaction);
    `uvm_object_utils(invalid_read_addr_test_seq)

    function new(string path = "invalid_read_addr_test_seq");
        super.new(path);
    endfunction

    transaction tr_rd;

    virtual task body();
        tr_rd = transaction::type_id::create("tr_rd");

        start_item(tr_rd);
        tr_rd.c_addr.constraint_mode(0);
      assert(tr_rd.randomize() with {
            op_mode == AXI_READ;
            len     == 0;
            size    == 2;
            burst   == 1;      // INCR
            // strb[0] == 4'b1111;
            addr > 128;
        });
        finish_item(tr_rd);
    endtask
endclass

// 13. invalid_write_size_test
class invalid_write_size_test_seq extends uvm_sequence #(transaction);
     `uvm_object_utils(invalid_write_size_test_seq)

    function new(string path = "invalid_write_size_test_seq");
        super.new(path);
    endfunction

    transaction tr_wr;

    virtual task body();
        tr_wr = transaction::type_id::create("tr_wr");

        start_item(tr_wr);
        tr_wr.c_size.constraint_mode(0);
        assert(tr_wr.randomize() with {
            op_mode == AXI_WRITE;
            len     == 0;
            size    > 2; // invalid size
            burst   == 1;      // INCR
            strb[0] == 4'b1111;
        });
        finish_item(tr_wr);
    endtask
endclass

// 14. invalid_read_size_test
class invalid_read_size_test_seq extends uvm_sequence #(transaction);
     `uvm_object_utils(invalid_read_size_test_seq)

    function new(string path = "invalid_read_size_test_seq");
        super.new(path);
    endfunction

    transaction tr_rd;

    virtual task body();
        tr_rd = transaction::type_id::create("tr_rd");

        start_item(tr_rd);
        tr_rd.c_size.constraint_mode(0);
        assert(tr_rd.randomize() with {
            op_mode == AXI_READ;
            len     == 0;
            size    > 2; // invalid size
            burst   == 1;      // INCR
        });
        finish_item(tr_rd);
    endtask
endclass

// 15. corner_address_test
class corner_address_test_seq extends uvm_sequence #(transaction);
    `uvm_object_utils(corner_address_test_seq)

    function new(string path = "corner_address_test_seq");
        super.new(path);
    endfunction

    transaction tr_wr;
    transaction tr_rd;

    int address_value[$] = '{0, 127, 128};

    virtual task body();

        foreach (address_value[i]) begin

            // ----------------------------------------------------
            // Valid corner address: addr = 0
            // Use 4-byte access
            // ----------------------------------------------------
            if (address_value[i] == 0) begin
                tr_wr = transaction::type_id::create("tr_wr");
                start_item(tr_wr);
                assert(tr_wr.randomize() with {
                    op_mode == AXI_WRITE;
                    addr    == address_value[i];
                    len     == 0;
                    size    == 2;
                    burst   == 1;
                    strb[0] == 4'b1111;
                });
                finish_item(tr_wr);
                tr_rd = transaction::type_id::create("tr_rd");
                start_item(tr_rd);
                assert(tr_rd.randomize() with {
                    op_mode == AXI_READ;
                    addr    == tr_wr.addr;
                    len     == tr_wr.len;
                    size    == tr_wr.size;
                    burst   == tr_wr.burst;
                });
                finish_item(tr_rd);

            end

            // ----------------------------------------------------
            // Valid corner address: addr = 127
            // Use 1-byte access to avoid crossing memory boundary
            // ----------------------------------------------------
            else if (address_value[i] == 127) begin
                tr_wr = transaction::type_id::create("tr_wr");
                start_item(tr_wr);
                assert(tr_wr.randomize() with {
                    op_mode == AXI_WRITE;
                    addr    == address_value[i];
                    len     == 0;
                    size    == 0;
                    burst   == 1;
                    strb[0] == 4'b0001;
                });
                finish_item(tr_wr);
                tr_rd = transaction::type_id::create("tr_rd");
                start_item(tr_rd);
                assert(tr_rd.randomize() with {
                    op_mode == AXI_READ;
                    addr    == tr_wr.addr;
                    len     == tr_wr.len;
                    size    == tr_wr.size;
                    burst   == tr_wr.burst;
                });
                finish_item(tr_rd);

            end


            // ----------------------------------------------------
            // Invalid corner address: addr = 128
            // Disable legal address constraint
            // ----------------------------------------------------
            else if (address_value[i] == 128) begin
                tr_wr = transaction::type_id::create("tr_wr");
                start_item(tr_wr);
                tr_wr.c_addr.constraint_mode(0);
                assert(tr_wr.randomize() with {
                    op_mode == AXI_WRITE;
                    addr    == address_value[i];
                    len     == 0;
                    size    == 2;
                    burst   == 1;
                    strb[0] == 4'b1111;
                });
                tr_wr.c_addr.constraint_mode(1);
                finish_item(tr_wr);
                tr_rd = transaction::type_id::create("tr_rd");
                start_item(tr_rd);
                tr_rd.c_addr.constraint_mode(0);
                assert(tr_rd.randomize() with {
                    op_mode == AXI_READ;
                    addr    == address_value[i];
                    len     == 0;
                    size    == 2;
                    burst   == 1;
                });
                tr_rd.c_addr.constraint_mode(1);
                finish_item(tr_rd);
            end
        end
    endtask
endclass

// 16. corner_data_test
class corner_data_test_seq extends uvm_sequence #(transaction);
    `uvm_object_utils(corner_data_test_seq)

    function new(string path = "corner_data_test_seq");
        super.new(path);
    endfunction

    transaction tr_wr;
    transaction tr_rd;

    bit [31:0] data_value[$] = '{
        32'h0000_0000,
        32'hFFFF_FFFF
    };

    virtual task body();

        foreach (data_value[i]) begin

            tr_wr = transaction::type_id::create("tr_wr");

            start_item(tr_wr);
            tr_wr.c_data.constraint_mode(0);
            assert(tr_wr.randomize() with {
                op_mode == AXI_WRITE;
                len     == 0;
                size    == 2;
                burst   == 1;
            });
            
            tr_wr.data_q[0] = data_value[i];
            tr_wr. strb[0] = 4'b1111;
            finish_item(tr_wr);


            tr_rd = transaction::type_id::create("tr_rd");

            start_item(tr_rd);
            assert(tr_rd.randomize() with {
                op_mode == AXI_READ;
                addr    == tr_wr.addr;
                len     == tr_wr.len;
                size    == tr_wr.size;
                burst   == tr_wr.burst;
            });
            finish_item(tr_rd);

        end

    endtask

endclass


// 17. pattern_test
class pattern_test_seq extends uvm_sequence #(transaction);
    `uvm_object_utils(pattern_test_seq)

    function new(string path = "pattern_test_seq");
        super.new(path);
    endfunction

    transaction tr_wr;
    transaction tr_rd;

    bit [31:0] pattern_value[$] = '{
        32'hAAAA_AAAA,
        32'h5555_5555,
        32'h0000_0001,
        32'h0000_0002,
        32'h0000_0004,
        32'h0000_0008,
        32'h0000_0010,
        32'h0000_0020,
        32'h0000_0040,
        32'h0000_0080
    };

    virtual task body();

        foreach (pattern_value[i]) begin

            tr_wr = transaction::type_id::create("tr_wr");

            start_item(tr_wr);
            tr_wr.c_data.constraint_mode(0);
            assert(tr_wr.randomize() with {
                op_mode == AXI_WRITE;
                len     == 0;
                size    == 2;
                burst   == 1;
            });
            
            tr_wr.data_q[0] = pattern_value[i];
            tr_wr.strb[0] = 4'b1111;
            finish_item(tr_wr);


            tr_rd = transaction::type_id::create("tr_rd");
            start_item(tr_rd);
            assert(tr_rd.randomize() with {
                op_mode == AXI_READ;
                addr    == tr_wr.addr;
                len     == tr_wr.len;
                size    == tr_wr.size;
                burst   == tr_wr.burst;
            });
            finish_item(tr_rd);

        end

    endtask
endclass


// 18. read_before_write_test
class read_before_write_test_seq extends uvm_sequence #(transaction);
    `uvm_object_utils(read_before_write_test_seq)

    function new(string path = "read_before_write_test_seq");
        super.new(path);
    endfunction

    transaction tr_rd;

    virtual task body();

        tr_rd = transaction::type_id::create("tr_rd");

        start_item(tr_rd);
        assert(tr_rd.randomize() with {
            op_mode == AXI_READ;
            len     == 0;
            size    == 2;
            burst   == 1;
        });
        finish_item(tr_rd);

    endtask
endclass


// 19. random_regression
class random_regression_seq extends uvm_sequence #(transaction);
    `uvm_object_utils(random_regression_seq)

    function new(string path = "random_regression_seq");
        super.new(path);
    endfunction

    transaction tr_wr;
    transaction tr_rd;

    virtual task body();

        repeat (50) begin

            tr_wr = transaction::type_id::create("tr_wr");

            start_item(tr_wr);
            assert(tr_wr.randomize() with {
                op_mode == AXI_WRITE;
            });
            finish_item(tr_wr);


            tr_rd = transaction::type_id::create("tr_rd");

            start_item(tr_rd);
            assert(tr_rd.randomize() with {
                op_mode == AXI_READ;
                addr    == tr_wr.addr;
                len     == tr_wr.len;
                size    == tr_wr.size;
                burst   == tr_wr.burst;
            });
            finish_item(tr_rd);
        end
    endtask
endclass


class driver extends uvm_driver #(transaction);
    `uvm_component_utils(driver)

    function new(string path = "driver", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    transaction tr_drv;
    virtual axi_if vif;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tr_drv = transaction::type_id::create("tr_drv", this);

        if (!uvm_config_db #(virtual axi_if)::get(this, "", "vif", vif))
            `uvm_error("DRV", "Unable to access the interface")
    endfunction

    task reset_dut();
        `uvm_info("DRV", "System Reset : Start of Simulation", UVM_MEDIUM);
        vif.resetn      <= 1'b0;  ///active low reset
        vif.awvalid     <= 1'b0;
        vif.awid        <= 1'b0;
        vif.awlen       <= 0;
        vif.awsize      <= 0;
        vif.awaddr      <= 0;
        vif.awburst     <= 0;
        
        vif.wvalid      <= 0;
        vif.wid         <= 0;
        vif.wdata       <= 0;
        vif.wstrb       <= 0;
        vif.wlast       <= 0;
        
        vif.bready      <= 0;
        
        vif.arvalid     <= 1'b0;
        vif.arid        <= 1'b0;
        vif.arlen       <= 0;
        vif.arsize      <= 0;
        vif.araddr      <= 0;
        vif.arburst     <= 0; 
        
        vif.rready      <= 0;
        repeat (2) @(posedge vif.clk);

        vif.resetn <= 1'b1;   // release reset

        repeat (1) @(posedge vif.clk);

        `uvm_info("DRV", "System Reset : Done", UVM_MEDIUM)
    endtask

    // disable write channel
    task disable_write();
            vif.awvalid <= 1'b0;
            vif.awid    <= '0;
            vif.awaddr  <= '0;
            vif.awlen   <= '0;
            vif.awsize  <= '0;
            vif.awburst <= '0;

            vif.wvalid  <= 1'b0;
            vif.wid     <= '0;
            vif.wdata   <= '0;
            vif.wstrb   <= '0;
            vif.wlast   <= '0;
            vif.bready  <= 1'b0;
    endtask

    // disable read channel
    task disable_read();
        // Disable read channel
        vif.arvalid <= 1'b0;
        vif.arid    <= '0;
        vif.araddr  <= '0;
        vif.arlen   <= '0;
        vif.arsize  <= '0;
        vif.arburst <= '0;
        vif.rready  <= 1'b0;
    endtask

    task drive_write();
        `uvm_info("DRV", "Starting AXI write transaction", UVM_MEDIUM)
        @(posedge vif.clk);
        //disable read
        disable_read();
        // drive write address channel
        vif.resetn <= 1'b1;
        vif.awvalid <= 1'b1;
        vif.awid <= tr_drv.id;
        vif.awaddr <= tr_drv.addr;
        vif.awlen <= tr_drv.len;
        vif.awsize <= tr_drv.size;
        vif.awburst <= tr_drv.burst;
        
        // drive write data channel
        vif.wvalid <= 1'b1;
        vif.wid <= tr_drv.id;
        $display("%0p", tr_drv.data_q);
        // continue sending the transactions in a transfer depends on the awlen
        for (int i = 0; i< tr_drv.data_q.size(); i++) begin
            vif.wdata <= tr_drv.data_q[i];
            vif.wstrb <= tr_drv.strb[i];
            @(posedge vif.wready);
            @(posedge vif.clk);
        end

        // fiinsh sending all transaction in a transfer
        vif.awvalid <= 1'b0;
        vif.wvalid <= 1'b0;
        vif.wlast <= 1'b1;
        vif.bready <= 1'b1;
        vif.wstrb <= 4'b0000;
        vif.wdata <= 0;
        @(negedge vif.bvalid); 
        vif.wlast <= 1'b0;
        vif.bready <= 1'b0;
        `uvm_info("DRV", "Complete AXI write transaction", UVM_MEDIUM)
    endtask
   

    task drive_read();
        `uvm_info("DRV", "Starting AXI read transaction", UVM_MEDIUM)
        @(posedge vif.clk);
        
        disable_write();
        vif.arvalid <= 1'b1;
        vif.arid <= tr_drv.id;
        vif.araddr <= tr_drv.addr;
        vif.arlen <= tr_drv.len;
        vif.arsize <= tr_drv.size;
        vif.arburst <= tr_drv.burst;
        // Master ready to accept data 
        vif.rready <= 1'b1;

        // wait for all read beats in the transfer
        for (int i = 0; i < tr_drv.len + 1; i++) begin
             @(posedge vif.rvalid);
             @(posedge vif.clk);
            //`uvm_info("DRV",$sformatf("Read beat %0d accepted: rvalid=%0b rready=%0b rlast=%0b rdata=%0d", i, vif.rvalid, vif.rready, vif.rlast, vif.rdata), UVM_MEDIUM)
        end
        
        @(negedge vif.rlast);
        // finish read transfer
        vif.arvalid <= 1'b0;
        vif.rready <= 1'b0;

        `uvm_info("DRV", "Completed AXI read transaction", UVM_MEDIUM)
    endtask

    virtual task run_phase(uvm_phase phase);
        //reset_dut();
      //`uvm_info("DRV", "DUT Initial Reset complete", UVM_MEDIUM)
        forever begin
            seq_item_port.get_next_item(tr_drv);
            case (tr_drv.op_mode)
                AXI_WRITE: begin
                    drive_write();
                end
                AXI_READ: begin
                    drive_read();
                end

                AXI_RESET: begin
                    reset_dut();
                end

                default: begin
                    `uvm_error("DRV", "Unknown AXI operation")
                end
            endcase
            seq_item_port.item_done();

$display("--------------------------------------------------------------------------------------------");
        end
    endtask
endclass



class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)

    function new(string path = "monitor", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    transaction tr_mon;
    virtual axi_if vif;
    uvm_analysis_port #(transaction) port;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tr_mon = transaction::type_id::create("tr_mon");
        port = new("port", this);

      if (!uvm_config_db #(virtual axi_if)::get(this, "", "vif", vif))
            `uvm_error("MON", "Unable to access interface")
    endfunction

    bit reset_seen;

    task collect_write();
        tr_mon.op_mode = AXI_WRITE;
        tr_mon.id = vif.awid;
        tr_mon.addr = vif.awaddr;
        tr_mon.len     = vif.awlen;
        tr_mon.size    = vif.awsize;
        tr_mon.burst   = vif.awburst;

        tr_mon.data_q.delete();
        tr_mon.strb.delete();
      
        //$display("Monitor start to collect all write beats");

        // collect all write beats
      for (int i = 0; i < vif.awlen + 1; i++) begin
            do begin
                @(posedge vif.clk);
            end while (!(vif.wvalid && vif.wready));
            tr_mon.data_q.push_back(vif.wdata);
            tr_mon.strb.push_back(vif.wstrb);
        end
        
        //$display("Monitor succesfully collect all write beats");

        // wait for B response
        while (!(vif.bvalid && vif.bready)) begin
            @(posedge vif.clk);
        end

        tr_mon.resp = vif.bresp;
        `uvm_info("MON", $sformatf("Monitor sample AXI_WRITE succesfully. awaddr: %0d | beats: %0d | data_q: %0p | strb: %0p | bresp: %0b",tr_mon.addr, tr_mon.len + 1, tr_mon.data_q , tr_mon.strb, tr_mon.resp), UVM_MEDIUM)

        port.write(tr_mon);   
    endtask

    task collect_read();
        tr_mon.op_mode = AXI_READ;
        tr_mon.id = vif.arid;
        tr_mon.addr = vif.araddr;
        tr_mon.len     = vif.arlen;
        tr_mon.size    = vif.arsize;
        tr_mon.burst   = vif.arburst;

        tr_mon.data_q.delete();
        tr_mon.strb.delete();

        // collect all read beats
      for (int i  = 0; i < vif.arlen + 1; i++) begin
            while (!(vif.rvalid && vif.rready)) begin
                @(posedge vif.clk);
            end 
           //`uvm_info("MON", $sformatf("READ beat %0d sampled: rdata=%0d rvalid=%0b rready=%0b rlast=%0b",i, vif.rdata, vif.rvalid, vif.rready, vif.rlast), UVM_MEDIUM)
            tr_mon.data_q.push_back(vif.rdata);
            tr_mon.resp = vif.rresp;
            @(posedge vif.clk);
        end
        
        `uvm_info("MON", $sformatf("Monitor sample AXI_READ succesfully. araddr: %0d | data_q: %0p | strb: %0p | bresp: %0b",tr_mon.addr, tr_mon.data_q, tr_mon.strb, tr_mon.resp), UVM_MEDIUM)
        port.write(tr_mon);
    endtask


      virtual task run_phase(uvm_phase phase);
        forever begin
            @(posedge vif.clk);

            if (!vif.resetn && !reset_seen) begin
                tr_mon.op_mode = AXI_RESET;
                `uvm_info("MON", "DUT RESET DETECTED", UVM_MEDIUM)
                port.write(tr_mon);
                reset_seen = 1;
                continue;
            end

            // reset the reset flag
            if (vif.resetn) begin
                reset_seen = 0;
            end

            if (vif.awvalid && vif.awready) begin
                //$display("Test sequence get to sample write");
                collect_write();
            end else if (vif.arvalid && vif.arready) begin
                //$display("Test sequence get to sample read");
                collect_read();

            end
        end
    endtask

endclass


class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    function new(string path = "scoreboard", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    transaction tr_sco;
    uvm_analysis_imp #(transaction, scoreboard) imp;
    bit [7:0] ref_mem[128];

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tr_sco = transaction::type_id::create("tr_sco");
        imp = new("imp", this);
    endfunction

    // return the size of each transaction/beat
    function int bytes_per_beat(bit [2:0] size);
        return (1 << size);
    endfunction

    // return the next address
    function bit [31:0] next_addr(
        bit [31:0] curr_addr,
        bit [1:0]  burst,
        bit [2:0]  size,
        bit [3:0]  len,
        bit [31:0] start_addr
    );

        int bytes;
        int beats;
        int boundary;

        bytes = bytes_per_beat(size);
        beats = len + 1;

        case (burst)
            2'b00: return curr_addr; // fix mode address burst
            2'b01: return curr_addr + bytes; // increment mode
            2'b10: begin
                // wrap mode address burst address algorithm
                boundary = beats * bytes;

                if (((curr_addr + bytes) % boundary) == 0) begin
                    return (curr_addr + bytes) - boundary;
                end else begin
                    return curr_addr + bytes;
                end
            end 

            default: return curr_addr;
        endcase
    endfunction

    virtual function void write(transaction data);
        tr_sco = data;
        case (tr_sco.op_mode)
            AXI_RESET: begin
                `uvm_info("SCO", "DUT RESET DETECTED", UVM_MEDIUM)
            end

            AXI_WRITE: begin
                bit [31:0] addr;

                addr = tr_sco.addr;

                if (tr_sco.resp != 2'b00) begin
                    `uvm_info("SCO", "Write response is error, reference memory not updated", UVM_MEDIUM)
                end 
                else begin
                    foreach (tr_sco.data_q[i]) begin
                        bit [31:0] beat_addr;

                        beat_addr = addr;

                        if (tr_sco.strb[i][0]) begin
                            if (beat_addr < 128)
                                ref_mem[beat_addr] = tr_sco.data_q[i][7:0];
                            beat_addr++;
                        end

                        if (tr_sco.strb[i][1]) begin
                            if (beat_addr < 128)
                                ref_mem[beat_addr] = tr_sco.data_q[i][15:8];
                            beat_addr++;
                        end

                        if (tr_sco.strb[i][2]) begin
                            if (beat_addr < 128)
                                ref_mem[beat_addr] = tr_sco.data_q[i][23:16];
                            beat_addr++;
                        end

                        if (tr_sco.strb[i][3]) begin
                            if (beat_addr < 128)
                                ref_mem[beat_addr] = tr_sco.data_q[i][31:24];
                            beat_addr++;
                        end

                        addr = next_addr(
                            addr,
                            tr_sco.burst,
                            tr_sco.size,
                            tr_sco.len,
                            tr_sco.addr
                        );
                    end

                    `uvm_info("SCO", "Reference memory updated for AXI write", UVM_MEDIUM)
                end
            end

            AXI_READ: begin
                bit [31:0] addr;
                bit [31:0] expected;

                addr = tr_sco.addr;

                if (tr_sco.resp != 2'b00) begin
                    `uvm_info("SCO", "Read response is error, skipping data comparison", UVM_MEDIUM)
                end
                else begin
                    foreach (tr_sco.data_q[i]) begin

                        expected = '0;

                    expected = '0;

                    case (tr_sco.size)
                        3'd0: begin
                            if (addr < 128)
                                expected[7:0] = ref_mem[addr];
                        end
                    
                        3'd1: begin
                            if (addr < 128)
                                expected[7:0] = ref_mem[addr];
                            if ((addr + 1) < 128)
                                expected[15:8] = ref_mem[addr + 1];
                        end
                    
                        3'd2: begin
                            if (addr < 128)
                                expected[7:0] = ref_mem[addr];
                            if ((addr + 1) < 128)
                                expected[15:8] = ref_mem[addr + 1];
                            if ((addr + 2) < 128)
                                expected[23:16] = ref_mem[addr + 2];
                            if ((addr + 3) < 128)
                                expected[31:24] = ref_mem[addr + 3];
                        end
                    endcase

                        if (tr_sco.data_q[i] !== expected) begin
                            `uvm_error("SCO",
                                $sformatf("READ MISMATCH beat = %0d | addr= %0d | expected = %0d | actual= %0d",
                                        i, addr, expected, tr_sco.data_q[i]))
                        end else begin
                            `uvm_info("SCO",
                                $sformatf("READ MATCH beat = %0d | addr = %0d | data = %0d",
                                        i, addr, tr_sco.data_q[i]), UVM_LOW)
                        end

                        addr = next_addr(addr, tr_sco.burst, tr_sco.size, tr_sco.len, tr_sco.addr);
                    end
                end
            end
        endcase
    endfunction
endclass

class agent extends uvm_agent;
    `uvm_component_utils(agent)

    function new(string path = "agent", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    driver drv;
    monitor mon;
    uvm_sequencer #(transaction) seqr;
    AXI_mem_config cfg;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = monitor::type_id::create("mon", this);
        cfg = AXI_mem_config::type_id::create("cfg");

        if (!uvm_config_db #(AXI_mem_config)::get(this, "", "cfg", cfg))
            `uvm_error("AGENT", "Unable to access AXI agent config")

        if (cfg.agent_type == UVM_ACTIVE) begin
            drv = driver::type_id::create("drv", this);
          seqr = uvm_sequencer#(transaction)::type_id::create("seqr", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
   
endclass

class env extends uvm_env;
    `uvm_component_utils(env)

    function new(string path = "env", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    agent a;
    scoreboard sco;
    AXI_mem_config cfg;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        a = agent::type_id::create("a", this);
        sco = scoreboard::type_id::create("sco", this);
        cfg = AXI_mem_config::type_id::create("cfg");

        uvm_config_db #(AXI_mem_config)::set(this, "a", "cfg", cfg);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        a.mon.port.connect(sco.imp);
    endfunction
endclass

class test extends uvm_test;
    `uvm_component_utils(test)

    function new(string path = "test", uvm_component parent = null);
        super.new(path, parent);
    endfunction
    
    env e;

    reset_test_seq                  reset_seq;
    single_write_test_seq           single_wr_seq;
    single_read_test_seq            single_rd_seq;
    write_read_test_seq             wr_rd_seq;
    fixed_burst_write_read_test_seq fixed_burst_seq;
    incr_burst_write_read_test_seq  incr_burst_seq;
    wrap_burst_write_read_test_seq  wrap_burst_seq;
    transfer_size_test_seq          transfer_size_seq;
    burst_length_test_seq           burst_length_seq;
    partial_strobe_test_seq         partial_strobe_seq;
    invalid_write_addr_test_seq     invalid_wr_addr_seq;
    invalid_read_addr_test_seq      invalid_rd_addr_seq;
    invalid_write_size_test_seq     invalid_wr_size_seq;
    invalid_read_size_test_seq      invalid_rd_size_seq;
    corner_address_test_seq         corner_addr_seq;
    corner_data_test_seq            corner_data_seq;
    pattern_test_seq                pattern_seq;
    read_before_write_test_seq      read_before_wr_seq;
    random_regression_seq           random_seq;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        e = env::type_id::create("e", this);

        reset_seq          = reset_test_seq::type_id::create("reset_seq");
        single_wr_seq      = single_write_test_seq::type_id::create("single_wr_seq");
        single_rd_seq      = single_read_test_seq::type_id::create("single_rd_seq");
        wr_rd_seq          = write_read_test_seq::type_id::create("wr_rd_seq");
        fixed_burst_seq    = fixed_burst_write_read_test_seq::type_id::create("fixed_burst_seq");
        incr_burst_seq     = incr_burst_write_read_test_seq::type_id::create("incr_burst_seq");
        wrap_burst_seq     = wrap_burst_write_read_test_seq::type_id::create("wrap_burst_seq");
        transfer_size_seq  = transfer_size_test_seq::type_id::create("transfer_size_seq");
        burst_length_seq   = burst_length_test_seq::type_id::create("burst_length_seq");
        partial_strobe_seq = partial_strobe_test_seq::type_id::create("partial_strobe_seq");
        invalid_wr_addr_seq = invalid_write_addr_test_seq::type_id::create("invalid_wr_addr_seq");
        invalid_rd_addr_seq = invalid_read_addr_test_seq::type_id::create("invalid_rd_addr_seq");
        invalid_wr_size_seq = invalid_write_size_test_seq::type_id::create("invalid_wr_size_seq");
        invalid_rd_size_seq = invalid_read_size_test_seq::type_id::create("invalid_rd_size_seq");
        corner_addr_seq    = corner_address_test_seq::type_id::create("corner_addr_seq");
        corner_data_seq    = corner_data_test_seq::type_id::create("corner_data_seq");
        pattern_seq        = pattern_test_seq::type_id::create("pattern_seq");
        read_before_wr_seq = read_before_write_test_seq::type_id::create("read_before_wr_seq");
        random_seq         = random_regression_seq::type_id::create("random_seq");
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        /* Pass these cases
        $display("-------------------------reset_seq_test----------------------");
        reset_seq.start(e.a.seqr);

      
		$display("-------------------------single_wr_seq_test----------------------");
        single_wr_seq.start(e.a.seqr);
      
        $display("-------------------------single_rd_seq_test----------------------");
        reset_seq.start(e.a.seqr);
        single_rd_seq.start(e.a.seqr);
      
        $display("-------------------------wr_rd_seq_test----------------------");
        reset_seq.start(e.a.seqr);
        wr_rd_seq.start(e.a.seqr);
 
        $display("-------------------------fixed_burst_seq_test----------------------");
        reset_seq.start(e.a.seqr);
        fixed_burst_seq.start(e.a.seqr);
        
        $display("-------------------------incr_burst_seq_test----------------------");
        reset_seq.start(e.a.seqr);
        incr_burst_seq.start(e.a.seqr);
        
        $display("-------------------------wrap_burst_seq_test----------------------");
        reset_seq.start(e.a.seqr);
        wrap_burst_seq.start(e.a.seqr);
      */
        
  
         /* Failed these cases because of INCR write address did not reliably advance between beats and 
            Internal burst state leaked across separate transactions
        $display("------------------------- transfer_size_seq_test----------------------");
        reset_seq.start(e.a.seqr);
        transfer_size_seq.start(e.a.seqr);
       
        $display("------------------------- burst_length_seq_test----------------------");
        reset_seq.start(e.a.seqr);
        burst_length_seq.start(e.a.seqr);
        
        
        $display("-------------------------  partial_strobe_seq_test----------------------");
        reset_seq.start(e.a.seqr);
        partial_strobe_seq.start(e.a.seqr);
        */
        
        /* Pass these cases
        $display("-------------------------invalid_wr_addr_seq_test----------------------");
        reset_seq.start(e.a.seqr);
        invalid_wr_addr_seq.start(e.a.seqr);
        
        $display("-------------------------invalid_rd_addr_seq_test----------------------");
        reset_seq.start(e.a.seqr);
        invalid_rd_addr_seq.start(e.a.seqr);
        
        $display("------------------------- invalid_wr_size_seq_test----------------------");
        reset_seq.start(e.a.seqr);
        invalid_wr_size_seq.start(e.a.seqr);
        
        $display("-------------------------invalid_rd_size_seq_test----------------------");
        reset_seq.start(e.a.seqr);
        invalid_rd_size_seq.start(e.a.seqr);
        */
        
         /* Pass these case
         $display("-------------------------corner_addr_seq_test----------------------");
         reset_seq.start(e.a.seqr);
         corner_addr_seq.start(e.a.seqr);
         
         
         $display("-------------------------corner_data_seq_test----------------------");
         reset_seq.start(e.a.seqr);
         corner_data_seq.start(e.a.seqr);
         */
         
         /* Pass these case, reset mechanic of DUT is not correct, not resetting the memories
         $display("-------------------------pattern_seq_test----------------------");
         reset_seq.start(e.a.seqr);
         pattern_seq.start(e.a.seqr);
       
         $display("-------------------------read_before_wr_seq_test----------------------");
         reset_seq.start(e.a.seqr); 
         read_before_wr_seq.start(e.a.seqr);
         */
        
        /* Fail this case because of those above error
        $display("-------------------------random_seq_test----------------------");
        reset_seq.start(e.a.seqr); 
        random_seq.start(e.a.seqr);
        */
        #100;


        phase.drop_objection(this);
    endtask

endclass


module tb;

    axi_if vif();
    axi_mem_slave dut (
        .clk      (vif.clk),
        .resetn   (vif.resetn),

        .awvalid  (vif.awvalid),
        .awready  (vif.awready),
        .awid     (vif.awid),
        .awaddr   (vif.awaddr),
        .awlen    (vif.awlen),
        .awsize   (vif.awsize),
        .awburst  (vif.awburst),

        .wvalid   (vif.wvalid),
        .wready   (vif.wready),
        .wid      (vif.wid),
        .wdata    (vif.wdata),
        .wstrb    (vif.wstrb),
        .wlast    (vif.wlast),

        .bvalid   (vif.bvalid),
        .bready   (vif.bready),
        .bresp    (vif.bresp),
      	.bid      (vif.bid),

        .arvalid  (vif.arvalid),
        .arready  (vif.arready),
        .arid     (vif.arid),
        .araddr   (vif.araddr),
        .arlen    (vif.arlen),
        .arsize   (vif.arsize),
        .arburst  (vif.arburst),

        .rvalid   (vif.rvalid),
        .rready   (vif.rready),
        .rid      (vif.rid),
        .rdata    (vif.rdata),
        .rresp    (vif.rresp),
        .rlast    (vif.rlast)
    );

    initial begin
        vif.clk <= 0;
    end

    always #10 vif.clk <= ~vif.clk; 

    initial begin
        uvm_config_db#(virtual axi_if)::set(null, "*", "vif", vif);
        run_test("test");
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;
    end
endmodule




