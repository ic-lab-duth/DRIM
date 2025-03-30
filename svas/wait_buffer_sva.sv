    assert property (@(posedge clk) disable iff(!rst_n) write_enable |-> !stat_counter[DEPTH]) else $error("ERROR:WT Buffer: Push on Full");
