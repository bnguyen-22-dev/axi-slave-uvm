`timescale 1ns / 1ps

// Passive protocol checks for the signal widths implemented by axi_mem_slave.
module axi_sva (
    input logic        clk,
    input logic        resetn,

    input logic        awvalid,
    input logic        awready,
    input logic [3:0]  awid,
    input logic [3:0]  awlen,
    input logic [2:0]  awsize,
    input logic [31:0] awaddr,
    input logic [1:0]  awburst,

    input logic        wvalid,
    input logic        wready,
    input logic [3:0]  wid,
    input logic [31:0] wdata,
    input logic [3:0]  wstrb,
    input logic        wlast,

    input logic        bvalid,
    input logic        bready,
    input logic [3:0]  bid,
    input logic [1:0]  bresp,

    input logic        arvalid,
    input logic        arready,
    input logic [3:0]  arid,
    input logic [3:0]  arlen,
    input logic [2:0]  arsize,
    input logic [31:0] araddr,
    input logic [1:0]  arburst,

    input logic        rvalid,
    input logic        rready,
    input logic [3:0]  rid,
    input logic [31:0] rdata,
    input logic [1:0]  rresp,
    input logic        rlast
);

    // A stalled write address must persist through the next sampled edge.
    property aw_hold_when_stalled;
        @(posedge clk) disable iff (!resetn)
        (awvalid && !awready) |=>
            (awvalid && $stable({awaddr, awid, awlen, awsize, awburst}));
    endproperty
    a_aw_hold_when_stalled: assert property (aw_hold_when_stalled)
        else $error("%m: AW master violation: AWVALID dropped or address/control changed after a stalled cycle");

    // Hold the entire write beat, including this project's WID, while stalled.
    property w_hold_when_stalled;
        @(posedge clk) disable iff (!resetn)
        (wvalid && !wready) |=>
            (wvalid && $stable({wdata, wstrb, wlast, wid}));
    endproperty
    a_w_hold_when_stalled: assert property (w_hold_when_stalled)
        else $error("%m: W master violation: WVALID dropped or data/strobe/last/ID changed after a stalled cycle");

    // The slave must retain an unaccepted write response.
    property b_hold_when_stalled;
        @(posedge clk) disable iff (!resetn)
        (bvalid && !bready) |=>
            (bvalid && $stable({bresp, bid}));
    endproperty
    a_b_hold_when_stalled: assert property (b_hold_when_stalled)
        else $error("%m: B slave violation: BVALID dropped or response/ID changed after a stalled cycle");

    // A stalled read address must persist through the next sampled edge.
    property ar_hold_when_stalled;
        @(posedge clk) disable iff (!resetn)
        (arvalid && !arready) |=>
            (arvalid && $stable({araddr, arid, arlen, arsize, arburst}));
    endproperty
    a_ar_hold_when_stalled: assert property (ar_hold_when_stalled)
        else $error("%m: AR master violation: ARVALID dropped or address/control changed after a stalled cycle");

    // Hold read data and all response metadata until the master accepts them.
    property r_hold_when_stalled;
        @(posedge clk) disable iff (!resetn)
        (rvalid && !rready) |=>
            (rvalid && $stable({rdata, rresp, rlast, rid}));
    endproperty
    a_r_hold_when_stalled: assert property (r_hold_when_stalled)
        else $error("%m: R slave violation: RVALID dropped or data/response/last/ID changed after a stalled cycle");

    // Sample reset behavior on clk; do not disable the checks during reset.
    // These check sampled levels, not immediate asynchronous reset propagation.
    property master_valids_low_in_reset;
        @(posedge clk)
        (!resetn) |-> ({awvalid, wvalid, arvalid} === 3'b000);
    endproperty
    a_master_valids_low_in_reset: assert property (master_valids_low_in_reset)
        else $error("%m: Master reset violation: AWVALID, WVALID and ARVALID must all be known low during reset");

    // The slave must not present write or read responses during sampled reset.
    property slave_valids_low_in_reset;
        @(posedge clk)
        (!resetn) |-> ({bvalid, rvalid} === 2'b00);
    endproperty
    a_slave_valids_low_in_reset: assert property (slave_valids_low_in_reset)
        else $error("%m: Slave reset violation: BVALID and RVALID must both be known low during reset");

endmodule
