assert property (@(posedge clk) disable iff(!rst_n) is_half |-> 1'b1) else $warning("Half Access Detected, two cycle fetch needed");
