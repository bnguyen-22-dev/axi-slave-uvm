`timescale 1ns / 1ps

// Passive SVA checker for the simplified AXI memory slave.
// These assertions verify DUT-specific behavior, not full AXI4 compliance.

module axi_sva (
    input logic        clk,
    input logic        resetn,

    // Write address channel
    input logic        awvalid,
    input logic        awready,
    input logic [31:0] awaddr,
    input logic [2:0]  awsize,

    // Write data channel
    input logic        wvalid,
    input logic        wready,

    // Write response channel
    input logic        bvalid,
    input logic [1:0]  bresp,

    // Read address channel
    input logic        arvalid,

    // Read data channel
    input logic        rvalid,

    // Internal DUT FSM states
    input logic [1:0]  awstate,
    input logic [2:0]  wstate
);

    // -------------------------------------------------------
    // 1. Master VALID signals must be low during reset
    // -------------------------------------------------------
    property master_reset;
        @(posedge clk)
        !resetn |-> ({awvalid, wvalid, arvalid} === 3'b000);
    endproperty

    a_master_reset: assert property (master_reset)
        else $error("SVA: Master VALID signals active during reset");


    // -------------------------------------------------------
    // 2. Slave response VALID signals must be low during reset
    // -------------------------------------------------------
    property slave_reset;
        @(posedge clk)
        !resetn |-> ({bvalid, rvalid} === 2'b00);
    endproperty

    a_slave_reset: assert property (slave_reset)
        else $error("SVA: Slave response VALID signals active during reset");


    // -------------------------------------------------------
    // 3. AWREADY must only be asserted in awreadys state
    // awreadys = 2
    // -------------------------------------------------------
    property awready_state;
        @(posedge clk) disable iff (!resetn)
        awready |-> (awstate == 2'd2);
    endproperty

    a_awready_state: assert property (awready_state)
        else $error("SVA: AWREADY asserted outside awreadys state");


    // -------------------------------------------------------
    // 4. WREADY must only be asserted in wreadys state
    // wreadys = 2
    // -------------------------------------------------------
    property wready_state;
        @(posedge clk) disable iff (!resetn)
        wready |-> (wstate == 3'd2);
    endproperty

    a_wready_state: assert property (wready_state)
        else $error("SVA: WREADY asserted outside wreadys state");


    // -------------------------------------------------------
    // 5. BRESP must match the DUT response logic
    // -------------------------------------------------------
    property bresp_valid;
        @(posedge clk) disable iff (!resetn)
        bvalid |->
        (
            ((awaddr < 128) && (awsize <= 2) && (bresp == 2'b00)) ||
            ((awsize > 2) && (bresp == 2'b10)) ||
            ((awaddr >= 128) && (awsize <= 2) && (bresp == 2'b11))
        );
    endproperty

    a_bresp_valid: assert property (bresp_valid)
        else $error("SVA: BRESP does not match DUT response logic");

endmodule