    assert property (@(posedge clk) disable iff(!rst_n) clk |-> !(branch_if>C_NUM)) else $fatal("RR: More branch in flight than max");
    assert property (@(posedge clk) disable iff(!rst_n) take_checkpoint |-> branch_if<C_NUM) else $fatal("RR: Max branch in flight reached");
    assert property (@(posedge clk) disable iff(!rst_n) (dual_branch && valid_o_2) |-> !(branch_if>C_NUM-2)) else $fatal("RR: Max branch in flight reached - 2");

    assert property (@(posedge clk) disable iff(!rst_n) fl_push |-> ((fl_data > 7 && fl_data < 16) || (fl_data > 31 && fl_data < 40))) else $fatal("Pushed Wrong Preg in FL");
    assert property (@(posedge clk) disable iff(!rst_n) (commit.valid_commit & ((commit.ldst > 7 && commit.ldst < 16) || (commit.ldst > 31 && commit.ldst < 40))) |-> fl_push) else $fatal("Did not push in FL");
    assert property (@(posedge clk) disable iff(!rst_n) (valid_o_1 && instr_a_rd_rename) |-> ((rob_requests.preg_1 > 7 && rob_requests.preg_1 < 16) || (rob_requests.preg_1 > 31 && rob_requests.preg_1 < 40))) else $fatal("Remaped to Wrong Preg -1");
    assert property (@(posedge clk) disable iff(!rst_n) (valid_o_2 && instr_b_rd_rename) |-> ((rob_requests.preg_2 > 7 && rob_requests.preg_2 < 16) || (rob_requests.preg_2 > 31 && rob_requests.preg_2 < 40))) else $fatal("Remaped to Wrong Preg -2");
    assert property (@(posedge clk) disable iff(!rst_n) valid_i_2 |-> valid_i_1) else $fatal("RR: Illegal Scenario");
    assert property (@(posedge clk) disable iff(!rst_n) fl_push |-> fl_ready) else $fatal("RR: Push on full FL");
    assert property (@(posedge clk) disable iff(!rst_n) (valid_i_1 && valid_i_2 && instruction_1.is_branch) |-> !instruction_2.is_branch) else $info("RR: Two branches in the same cycle");

    //-----------------------------------------------------------------------------
    //BENCHMARKING COUNTER SECTION
    //-----------------------------------------------------------------------------

    logic [63:0] total_allocations, total_reclaims, reclaim_stalls;
    assign reclaim_stalls = 0;
    always_ff @(posedge clk or negedge rst_n) begin : Alloc
        if(~rst_n) begin
            total_allocations <= 0;
        end else begin
            if(do_alloc_1 && do_alloc_2) begin
                total_allocations <= total_allocations +2;
            end else if(do_alloc_1 || do_alloc_2) begin
                total_allocations <= total_allocations +1;
            end
        end
    end
    always_ff @(posedge clk or negedge rst_n) begin : RECL
        if(~rst_n) begin
            total_reclaims <= 0;
        end else begin
            if(fl_push) begin
                total_reclaims <= total_reclaims +1;
            end
        end
    end
    //-----------------------------------------------------------------------------
    //DEBUGGING COUNTER SECTION
    //-----------------------------------------------------------------------------
    logic [2:0] branch_if;
    always_ff @(posedge clk or negedge rst_n) begin : BranchInFlight
        if(!rst_n) begin
            branch_if <= 0;
        end else begin
            if(flush_valid) begin
                branch_if <= 0;
            end else if(dual_branch && valid_o_2) begin
                branch_if <= branch_if + 2;
            end else if(take_checkpoint) begin
                if(!pr_update.valid_jump) begin
                    branch_if <= branch_if + 1;
                end
            end else if (pr_update.valid_jump && |branch_if) begin
                branch_if <= branch_if - 1;
            end
        end
    end