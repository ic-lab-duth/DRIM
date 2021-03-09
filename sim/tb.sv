`include "structs.sv"
module tb();

logic   rst_n, clk;
integer f,c;

//Initialize the Module
    module_top  module_top(
        .clk    (clk),
        .rst_n  (rst_n)
        );
// generate clock
always
    begin
    clk = 1; #5; clk = 0; #5;
end
//Initialize the Files
task sim_initialize;
    f = $fopen("flushes.txt","w");
    c = $fopen("commits.txt","w");
    $display("Testbench Starting...");
    if (tb.module_top.DUAL_ISSUE) begin
        $fwrite(f,"--Dual Issue Enabled--\n");
        $fwrite(c,"--Dual Issue Enabled--\n");
    end else begin
        $fwrite(f,"--Dual Issue Disabled--\n");
        $fwrite(c,"--Dual Issue Disabled--\n");
    end
endtask

task sim_finish;
    $fclose(f);
    $fclose(c);
    $display("Testbench End (or deadlock) detected...");
    $finish;
endtask

logic [32-1:0] old_pc;
logic pc_still_unchanged;
logic sim_finished;
int   cycles_pc_unchanged;

// Detect simulation end when PC hangs, since that is what the bootstrap is using
assign pc_still_unchanged = (old_pc == tb.module_top.current_pc);
assign sim_finished       = (cycles_pc_unchanged == 500) & rst_n;

always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        cycles_pc_unchanged <= 0;
    end else begin
        if(pc_still_unchanged) begin
            cycles_pc_unchanged <= cycles_pc_unchanged +1;
        end else begin
            cycles_pc_unchanged <= 0;
            old_pc <= tb.module_top.current_pc;
        end
    end
end

initial begin
    sim_initialize();
    rst_n=1;
    @(posedge clk);
    rst_n=0;
    @(posedge clk);
    rst_n=1;
    @(posedge clk);
    $display("Testbench Starting...");
    @(posedge clk);@(posedge clk);
    wait(sim_finished);
    @(posedge clk);
    sim_finish();
end
//--------------------------------------------------------
//DEBUGGING SECTION
//--------------------------------------------------------
logic [64-1:0][32-1 : 0] final_regfile;
writeback_toARF        writeback ;
logic           [31:0] f_address ;
logic           [ 2:0] f_r_ticket;
logic           [ 1:0] f_rat     ;
logic                  f_delayed ;
logic           [ 5:0] index     ;

always_comb begin : FinalRegFile
    for (int i = 0; i < 64; i++) begin
        if(i>7 & i<16) begin
            index            = tb.module_top.top_processor.rr.rat.CurrentRAT[i[2:0]];
            final_regfile[i] = tb.module_top.top_processor.issue.regfile.RegFile[index];
        end else begin
            index            = 0;
            final_regfile[i] = tb.module_top.top_processor.issue.regfile.RegFile[i];
        end
    end
end

assign f_address  = tb.module_top.top_processor.flush_address;
assign f_r_ticket = tb.module_top.top_processor.flush_rob_ticket;
assign f_rat      = tb.module_top.top_processor.flush_rat_id;
assign f_delayed  = tb.module_top.top_processor.idecode.flush_controller.delayed_capture;
assign writeback  = tb.module_top.top_processor.retired_instruction_o;

always @(posedge clk) begin
    if(tb.module_top.top_processor.flush_valid) begin
        $fwrite(f,"time:%d  adr:%h  rob:%d  rat:%d  delayed:%h \n",$time, f_address,f_r_ticket,f_rat,f_delayed);
    end
end
always @(posedge clk) begin
    if(writeback.valid_commit && !writeback.flushed && writeback.valid_write) begin
        $fwrite(c,"time:%d  preg:%d  data:%h \n",$time, writeback.pdst, writeback.data);
    end
end


endmodule