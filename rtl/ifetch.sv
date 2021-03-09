/*
* @info Intruction Fetch Stage
* @info Sub Modules: Predictor.sv, icache.sv
*
* @author VLSI Lab, EE dept., Democritus University of Thrace
*
* @brief The first stage of the processor. It contains the predictor and the icache
*
*/
`ifdef MODEL_TECH
    `include "structs.sv"
`endif
module ifetch #(
    parameter int PC_BITS          = 32  ,
    parameter int INSTR_BITS       = 32  ,
    parameter int RAS_DEPTH        = 8   ,
    parameter int GSH_HISTORY_BITS = 2   ,
    parameter int GSH_SIZE         = 256 ,
    parameter int BTB_SIZE         = 256)
    //Input List
    (
    input  logic  clk,
    input  logic  rst_n,
    //Output Interface
    output logic[2*PC_BITS-1:0]       data_out,
    output logic                      taken_branch,
    output logic                      valid_o,
    input  logic                      ready_in,
    //Predictor Update Interface
    input  logic                      is_branch,
    input  predictor_update           pr_update,
    //Restart Interface
    input  logic                      invalid_instruction,
    input  logic                      invalid_prediction,
    input  logic                      is_return_in,
    input  logic                      is_jumpl,
    input  logic[PC_BITS-1:0]         old_pc,
    //Flush Interface
    input  logic                      must_flush,
    input  logic[PC_BITS-1:0]         correct_address,
    //ICache Interface
    output logic    [PC_BITS-1:0]     current_pc,
    input  logic                      hit_cache,
    input  logic                      miss,
    input  logic                      is_half,
    input  logic  [INSTR_BITS-1:0]    instruction_out_cache
);

    typedef enum logic[1:0] {NONE, LOW, HIGH} override_priority;
    logic [INSTR_BITS-1:0] instruction_out;
    logic [PC_BITS-1:0]    next_pc, pc_orig, target_pc, saved_pc, next_pc_saved;
    logic [PC_BITS/2-1:0]  half_saved_instr;
    override_priority      over_priority;
    logic                  hit, new_entry, is_taken, is_return, is_return_fsm;
    logic                  taken_branch_saved, taken_branch_pr, half_access;

    assign data_out = half_access? {current_pc-2, instruction_out} : {current_pc, instruction_out};
    assign valid_o  = hit & (over_priority==NONE) & ~(is_return_in | is_return_fsm) & ~invalid_prediction & ~must_flush & ~invalid_instruction;

    //Intermidiate Signals
    assign new_entry = pr_update.valid_jump;
    assign pc_orig   = pr_update.orig_pc;
    assign target_pc = pr_update.jump_address;
    assign is_taken  = pr_update.jump_taken;

    assign is_return = (is_return_in | is_return_fsm) & hit;      //- Might need to use FSM for is_return_in if it's not constantly supplied from the IF/ID
    always_ff @(posedge clk or negedge rst_n) begin : returnFSM
        if(!rst_n) begin
            is_return_fsm <= 0;
        end else begin
            if(!is_return_fsm && is_return_in && !hit) begin
                is_return_fsm <= ~must_flush;
            end else if(is_return_fsm && hit) begin
                is_return_fsm <= 0;
            end
        end
    end

    predictor #(
        .PC_BITS         (PC_BITS         ),
        .RAS_DEPTH       (RAS_DEPTH       ),
        .GSH_HISTORY_BITS(GSH_HISTORY_BITS),
        .GSH_SIZE        (GSH_SIZE        ),
        .BTB_SIZE        (BTB_SIZE        )
    ) predictor (
        .clk            (clk                 ),
        .rst_n          (rst_n               ),

        .must_flush     (must_flush          ),
        .is_branch      (is_branch           ),
        .branch_resolved(pr_update.valid_jump),

        .new_entry      (new_entry           ),
        .pc_orig        (pc_orig             ),
        .target_pc      (target_pc           ),
        .is_taken       (is_taken            ),

        .is_return      (is_return           ),
        .is_jumpl       (is_jumpl            ),
        .invalidate     (invalid_prediction  ),
        .old_pc         (old_pc              ),

        .pc_in          (current_pc          ),
        .taken_branch   (taken_branch_pr     ),
        .next_pc        (next_pc             )
    );

    // Create the Output
    assign instruction_out = half_access ? {instruction_out_cache[PC_BITS/2-1:0],half_saved_instr} : instruction_out_cache;
    assign taken_branch    = half_access ? taken_branch_saved : taken_branch_pr;
    assign hit             = hit_cache & ~is_half;

    // Two-Cycle Fetch FSM
    always_ff @(posedge clk or negedge rst_n) begin : isHalf
        if(!rst_n) begin
            half_access <= 0;
        end else begin
            if(is_half && !half_access && hit_cache) begin
                half_access <= ~(invalid_prediction | invalid_instruction | is_return_in | must_flush | over_priority!=NONE);
            end else if(half_access && hit && ready_in) begin
                half_access <= 0;
            end else if(half_access && hit_cache) begin
                half_access <= ~((over_priority!=NONE) | invalid_prediction | invalid_instruction | is_return_in | must_flush);
            end
        end
    end
    // Half Instruction Management
    always_ff @(posedge clk) begin : HalfInstr
        if(is_half && !half_access && hit_cache) begin
            half_saved_instr   <= instruction_out_cache[PC_BITS/2-1:0];
            taken_branch_saved <= taken_branch_pr;
            next_pc_saved      <= next_pc;
        end
    end
    // PC Address Management
    always_ff @(posedge clk or negedge rst_n) begin : PCManagement
        if(!rst_n) begin
            current_pc <= 0;
        end else begin
            // Normal Operation
            if(hit_cache) begin
                if(over_priority==HIGH) begin
                    current_pc <= saved_pc;
                end else if(must_flush) begin
                    current_pc <= correct_address;
                end else if(over_priority==LOW && is_return_fsm) begin
                    current_pc <= next_pc;
                end else if(over_priority==LOW) begin
                    current_pc <= saved_pc;
                end else if(invalid_prediction) begin
                    current_pc <= old_pc;
                end else if (invalid_instruction) begin
                    current_pc <= old_pc;
                end else if (is_return_in) begin
                    current_pc <= next_pc;
                end else if(is_half) begin
                    current_pc <= current_pc +2;
                end else if (ready_in && !half_access) begin
                    current_pc <= next_pc;
                end else if (ready_in && half_access) begin
                    current_pc <= next_pc_saved;
                end
            end
        end
    end
    //Override FSM used to indicate a redirection must happen after cache unblocks
        //Flushing takes priority due to being an older instruction
    always_ff @(posedge clk or negedge rst_n) begin : overrideManagement
        if(!rst_n) begin
            over_priority <= NONE;
        end else begin
            if(must_flush && over_priority!=HIGH && !hit_cache) begin
                over_priority <= HIGH;
                saved_pc      <= correct_address;
            end else if(invalid_prediction && over_priority==NONE && !hit_cache) begin
                over_priority <= LOW;
                saved_pc      <= old_pc;
            end else if(invalid_instruction && over_priority==NONE && !hit_cache) begin
                over_priority <= LOW;
                saved_pc      <= old_pc;
            end else if(is_return_in && over_priority==NONE && !hit_cache) begin
                over_priority <= LOW;
                saved_pc      <= old_pc;
            end else if(hit_cache) begin
                over_priority <= NONE;
            end
        end
    end

    //BENCHMARKING COUNTER SECTION
    logic [63:0] redir_realign, redir_prediction, redir_return, redirections, flushes;
    logic        redirect, alignment_redirect, fnct_return_redirect, flush_redirect;

    assign fnct_return_redirect = hit & ~valid_o & invalid_instruction;
    assign alignment_redirect   = hit & ~valid_o & invalid_instruction;
    assign redirect             = hit & ~valid_o;
    assign flush_redirect       = hit & ~valid_o & must_flush;

    always_ff @(posedge clk or negedge rst_n) begin : ReDir
        if(!rst_n) begin
            redir_realign    <= 0;
            redir_prediction <= 0;
            redir_return     <= 0;
            flushes          <= 0;
            redirections     <= 0;
        end else begin
            if(alignment_redirect) begin
                redir_realign <= redir_realign +1;
            end
            if(invalid_prediction) begin
                redir_prediction <= redir_prediction +1;
            end
            if(fnct_return_redirect) begin
                redir_return <= redir_return +1;
            end
            if(flush_redirect) begin
                flushes <= flushes +1;
            end
            if(redirect) begin
                redirections <= redirections +1;
            end
        end
    end

`ifdef INCLUDE_SVAS
    `include "ifetch_sva.sv"
`endif

endmodule