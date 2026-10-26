`ifdef I02_SVA

assert done_pulse:
    assert property (@(posedge clk) done |=> !done);

assert no_unknown:
    assert property (@(posedge clk)
        !((^({root,busy,done})) === 1'bx));

`endif
