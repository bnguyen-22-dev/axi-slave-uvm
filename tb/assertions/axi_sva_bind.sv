bind axi_mem_slave axi_sva axi_sva_inst (
    .clk      (clk),
    .resetn   (resetn),

    .awvalid  (awvalid),
    .awready  (awready),
    .awaddr   (awaddr),
    .awsize   (awsize),

    .wvalid   (wvalid),
    .wready   (wready),

    .bvalid   (bvalid),
    .bresp    (bresp),

    .arvalid  (arvalid),
    .rvalid   (rvalid),

    .awstate  (awstate),
    .wstate   (wstate)
);