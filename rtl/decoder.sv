/*
* @info Decoder
* @info Sub-Modules: decoder_full.sv, decoder_comp.sv
*
* @author VLSI Lab, EE dept., Democritus University of Thrace
*
* @note Functional Units:
* 00 : Load/Store Unit
* 01 : Floating Point Unit
* 10 : Integer Unit
* 11 : Branches
*
* @param INSTR_BITS: # of Instruction Bits (default 32 bits)
* @param PC_BITS   : # of PC Bits (default 32 bits)
*/
`ifdef MODEL_TECH
    `include "structs.sv"
`endif
// `include "enum.sv"
module decoder #(INSTR_BITS = 32, PC_BITS=32) (
    input  logic                  clk                ,
    input  logic                  rst_n              ,
    //Port towards IS
    input  logic                  valid_i            ,
    output logic                  ready_o            ,
    input  logic                  taken_branch       ,
    input  logic [   PC_BITS-1:0] pc_in              ,
    input  logic [INSTR_BITS-1:0] instruction_in     ,
    //Output Port towards IF (Redirection Ports)
    output logic                  invalid_instruction,
    output logic                  invalid_prediction ,
    output logic                  is_return_out      ,
    output logic                  is_jumpl_out       ,
    output logic [   PC_BITS-1:0] old_pc             ,
    //Output Port towards Flush Controller
    output logic                  valid_transaction  ,
    output logic                  valid_branch_32    ,
    output logic                  valid_branch_16a   ,
    output logic                  valid_branch_16b   ,
    //Port towards IS (instruction queue)
    input  logic                  ready_i            , //must indicate at least 2 free slots in queue
    output logic                  valid_o            , //indicates first push
    output decoded_instr          output1            ,
    output logic                  valid_o_2          , //indicates second push
    output decoded_instr          output2            ,
    //Benchmarking Ports
    input  logic                  second_port_free
);

    // #Internal Signals#
    decoded_instr output_full, output_a,output_b;
    logic         must_restart_32, must_restart_16a, must_restart_16b;
    logic         valid, valid_32, valid_16a, valid_16b;
    logic         is_jumpl, is_return_32, is_return_16a, is_return_16b;

    assign valid             = valid_i & ready_i;
    assign ready_o           = ready_i;
    assign valid_o           = valid & ~invalid_prediction;
    assign valid_o_2         = valid & ~invalid_prediction & valid_16b & ~is_return_16a;
    assign valid_transaction = valid_o;
    //Check if incoming instruction is 32 bit or 2 compressed 16 bit
    always_comb begin : validity
        //valid 32 bit instruction
        if(instruction_in[1:0]==2'b11 && instruction_in[4:2]!=3'b111) begin
            valid_32  = valid;
            valid_16a = 1'b0;
            valid_16b = 1'b0;
            //valid first compressed instruction
        end else if (instruction_in[1:0]!=2'b11) begin
            valid_32  = 1'b0;
            valid_16a = valid;
            valid_16b = valid & (instruction_in[17:16]!=2'b11);
        end else begin
            valid_32  = 1'b0;
            valid_16a = 1'b0;
            valid_16b = 1'b0;
        end
    end
    //Initialize 1 full-decoder for the 32-bit Instructions (full length instructions)
    decoder_full #(INSTR_BITS,PC_BITS) decoder_full (
        .clk             (clk             ),
        .rst_n           (rst_n           ),
        .valid           (valid_32        ),
        .pc_in           (pc_in           ),
        .instruction_in  (instruction_in  ),
        .outputs         (output_full     ),
        .valid_branch    (valid_branch_32 ),
        .is_jumpl        (is_jumpl        ),
        .is_return       (is_return_32    ),
        .second_port_free(second_port_free)
    );
    //Initialize 2 small decoders for the 16-bit Instructions (compressed instructions)
    decoder_comp #(16,PC_BITS) decoder_comp_a (
        .clk           (clk                 ),
        .rst_n         (rst_n               ),
        .valid         (valid_16a           ),
        .pc_in         (pc_in               ),
        .instruction_in(instruction_in[15:0]),
        .outputs       (output_a            ),
        .is_return     (is_return_16a       ),
        .valid_branch  (valid_branch_16a    )
    );
    decoder_comp #(16,PC_BITS) decoder_comp_b (
        .clk           (clk                  ),
        .rst_n         (rst_n                ),
        .valid         (valid_16b            ),
        .pc_in         (pc_in+2              ),
        .instruction_in(instruction_in[31:16]),
        .outputs       (output_b             ),
        .is_return     (is_return_16b        ),
        .valid_branch  (valid_branch_16b     )
    );

    //Restart the Fetch on misPredicted taken on non-branch instruction
    assign invalid_prediction = must_restart_32 | must_restart_16a | must_restart_16b;
    assign must_restart_32    = taken_branch & ~valid_branch_32 & output_full.is_valid;
    assign must_restart_16a   = taken_branch & ~valid_branch_16a & output_a.is_valid;
    assign must_restart_16b   = 1'b0;
    always_comb begin : OldPC
        if(must_restart_16b) begin
            old_pc = pc_in +2;
        end else if(!valid_32 && !output_b.is_valid) begin
            old_pc = pc_in +2;
        end else begin
            old_pc = pc_in;
        end
    end
    //Pick the Decoded Outputs
    assign output1 = (valid_32)? output_full : output_a;
    assign output2 = output_b;

    assign is_jumpl_out = is_jumpl  & valid & output_full.is_valid;
    assign is_return_out = valid & ((is_return_32 && output_full.is_valid)
        | (is_return_16a && output_a.is_valid) | (is_return_16b && output_b.is_valid));

    //Restart due to misaligned - invalid instructions
    always_comb begin : Invalidation
        if(valid_32) begin
            invalid_instruction = valid & ~output_full.is_valid;
        end else begin
            invalid_instruction = valid & (~output_a.is_valid | ~output_b.is_valid );
        end
    end

endmodule