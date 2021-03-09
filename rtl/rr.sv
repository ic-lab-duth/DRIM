/*
* @info Register Renaming
* @info Sub-Modules: RAT.sv, FL.sv
*
* @author VLSI Lab, EE dept., Democritus University of Thrace
*
* @param P_REGISTERS   : # of Physical Registers
* @param L_REGISTERS   : # of Logical Registers
* @param ROB_INDEX_BITS: # of ROB ticket's bits
* @param C_NUM         : # of Checkpoints
*/
`ifdef MODEL_TECH
    `include "structs.sv"
`endif
module rr #(
    parameter P_REGISTERS    = 32,
    parameter L_REGISTERS    = 32,
    parameter ROB_INDEX_BITS = 3 ,
    parameter C_NUM          = 2
) (
    input  logic                     clk            ,
    input  logic                     rst_n          ,
    //Port towards ID
    output logic                     ready_o        ,
    input  logic                     valid_i_1      ,
    input  decoded_instr             instruction_1  ,
    input  logic                     valid_i_2      ,
    input  decoded_instr             instruction_2  ,
    //Port towards IS
    input  logic                     ready_i        ,
    output logic                     valid_o_1      ,
    output renamed_instr             instruction_o_1,
    output logic                     valid_o_2      ,
    output renamed_instr             instruction_o_2,
    //Port towards ROB
    input  to_issue                  rob_status     ,
    output new_entries               rob_requests   ,
    //Commit Port
    input  writeback_toARF           commit         ,
    //Flush Port
    input  logic                     flush_valid    ,
    input predictor_update           pr_update      ,
    input  logic [$clog2(C_NUM)-1:0] flush_rat_id
);

    // #Local Parameters#
    localparam P_ADDR_WIDTH = $clog2(P_REGISTERS);
    localparam L_ADDR_WIDTH = $clog2(L_REGISTERS);
    // #Internal Signals#
    logic [P_ADDR_WIDTH-1 : 0] alloc_p_reg_1, alloc_p_reg_2, ppreg_1, ppreg_2, fl_data;
    logic [P_ADDR_WIDTH-1 : 0] instr1_source1_rat, instr1_source2_rat, instr1_source3_rat;
    logic [P_ADDR_WIDTH-1 : 0] instr2_source1_rat, instr2_source2_rat, instr2_source3_rat;
    logic [ROB_INDEX_BITS-1:0] stalled_ticket    ;
    logic [ $clog2(C_NUM)-1:0] current_id        ;
    logic                      do_alloc_1, do_alloc_2, rat_push;
    logic                      fl_ready, fl_push, fl_valid_1, fl_valid_2;
    logic                      instr_a_rd_rename, instr_a_s1_rename, instr_a_s2_rename, instr_a_s3_rename;
    logic                      instr_b_rd_rename, instr_b_s1_rename, instr_b_s2_rename, instr_b_s3_rename;
    logic                      dual_branch       ;

    //First Instruction
    assign instr_a_rd_rename = (instruction_1.destination > 7) & (instruction_1.destination < 16);
    assign instr_a_s1_rename = (instruction_1.source1     > 7) & (instruction_1.source1 < 16);
    assign instr_a_s2_rename = (instruction_1.source2     > 7) & (instruction_1.source2 < 16);
    assign instr_a_s3_rename = (instruction_1.source3     > 7) & (instruction_1.source3 < 16);

    assign instruction_o_1.pc                = instruction_1.pc;
    assign instruction_o_1.source1_pc        = instruction_1.source1_pc;
    assign instruction_o_1.source2_immediate = instruction_1.source2_immediate;
    assign instruction_o_1.immediate         = instruction_1.immediate;
    assign instruction_o_1.functional_unit   = instruction_1.functional_unit;
    assign instruction_o_1.microoperation    = instruction_1.microoperation;
    assign instruction_o_1.rm                = instruction_1.rm;
    assign instruction_o_1.is_valid          = instruction_1.is_valid;
    assign instruction_o_1.rat_id            = current_id;
    assign instruction_o_1.source1           = !instr_a_s1_rename ? instruction_1.source1 : instr1_source1_rat;
    assign instruction_o_1.source2           = !instr_a_s2_rename ? instruction_1.source2 : instr1_source2_rat;
    assign instruction_o_1.source3           = !instr_a_s3_rename ? instruction_1.source3 : instr1_source3_rat;
    assign instruction_o_1.destination       = !instr_a_rd_rename ? instruction_1.destination : alloc_p_reg_1;
    assign instruction_o_1.ticket            = rob_status.ticket;

    //Second Instruction
    assign instr_b_rd_rename = (instruction_2.destination > 7) & (instruction_2.destination < 16);
    assign instr_b_s1_rename = (instruction_2.source1 > 7) & (instruction_2.source1 < 16);
    assign instr_b_s2_rename = (instruction_2.source2 > 7) & (instruction_2.source2 < 16);
    assign instr_b_s3_rename = (instruction_2.source3 > 7) & (instruction_2.source3 < 16);

    assign instruction_o_2.pc                = instruction_2.pc;
    assign instruction_o_2.source1_pc        = instruction_2.source1_pc;
    assign instruction_o_2.source2_immediate = instruction_2.source2_immediate;
    assign instruction_o_2.immediate         = instruction_2.immediate;
    assign instruction_o_2.functional_unit   = instruction_2.functional_unit;
    assign instruction_o_2.microoperation    = instruction_2.microoperation;
    assign instruction_o_2.rm                = instruction_2.rm;
    assign instruction_o_2.ticket            = rob_status.ticket+1;
    assign instruction_o_2.is_valid          = instruction_2.is_valid;
    assign instruction_o_2.rat_id            = instruction_1.is_branch ? current_id+1 : current_id;
    //Create the Instr #2 source1
    always_comb begin : I2R1
        if(instruction_2.source1 == instruction_1.destination) begin
            instruction_o_2.source1 = instruction_o_1.destination;
        end else if(instr_b_s1_rename) begin
            instruction_o_2.source1 = instr2_source1_rat;
        end else begin
            instruction_o_2.source1 = instruction_2.source1;
        end
    end
    //Create the Instr #2 source2
    always_comb begin : I2R2
        if(instruction_2.source2 == instruction_1.destination) begin
            instruction_o_2.source2 = instruction_o_1.destination;
        end else if(instr_b_s2_rename) begin
            instruction_o_2.source2 = instr2_source2_rat;
        end else begin
            instruction_o_2.source2 = instruction_2.source2;
        end
    end
    //Create the Instr #2 source3
    always_comb begin : I2R3
        if(instruction_2.source3 == instruction_1.destination) begin
            instruction_o_2.source3 = instruction_o_1.destination;
        end else if(instr_b_s3_rename) begin
            instruction_o_2.source3 = instr2_source3_rat;
        end else begin
            instruction_o_2.source3 = instruction_2.source3;
        end
    end
    //Create the Instr #2 destination
    always_comb begin : I2RD
        if (instr_a_rd_rename && instr_b_rd_rename) begin
            instruction_o_2.destination = alloc_p_reg_2;
        end else if (!instr_a_rd_rename && instr_b_rd_rename) begin
            instruction_o_2.destination = alloc_p_reg_1;
        end else begin
            instruction_o_2.destination = instruction_2.destination;
        end
    end
    //New ROB Requests to reserve entries
    assign rob_requests.valid_request_1  = valid_o_1;
    assign rob_requests.valid_dest_1     = |instruction_o_1.destination;
    assign rob_requests.lreg_1           = instruction_1.destination;
    assign rob_requests.preg_1           = instruction_o_1.destination;
    assign rob_requests.ppreg_1          = ppreg_1;
    assign rob_requests.microoperation_1 = instruction_1.microoperation;

    assign rob_requests.valid_request_2  = valid_o_2;
    assign rob_requests.valid_dest_2     = |instruction_o_2.destination;
    assign rob_requests.lreg_2           = instruction_2.destination;
    assign rob_requests.preg_2           = instruction_o_2.destination;
    assign rob_requests.ppreg_2          = (instruction_1.destination == instruction_2.destination) ? instruction_o_1.destination : ppreg_2;
    assign rob_requests.microoperation_2 = instruction_2.microoperation;

    //Control Flow
    assign ready_o = valid_o_1 | flush_valid;
    always_comb begin : ValidOutput
        if(valid_i_1 && valid_i_2) begin
            if(instr_a_rd_rename && instr_b_rd_rename) begin
                valid_o_1 = ready_i & fl_valid_1 & fl_valid_2 & ~flush_valid & ~rob_status.is_full & rob_status.two_empty;
            end else if(instr_a_rd_rename || instr_b_rd_rename) begin
                valid_o_1 = ready_i & fl_valid_1 & ~flush_valid & ~rob_status.is_full & rob_status.two_empty;
            end else begin
                valid_o_1 = ready_i & ~flush_valid & ~rob_status.is_full & rob_status.two_empty;
            end
            valid_o_2 = valid_o_1;
        end else if(valid_i_1 && !valid_i_2) begin
            valid_o_1 = instr_a_rd_rename ? ready_i & fl_valid_1 & ~flush_valid & ~rob_status.is_full : ready_i & ~flush_valid & ~rob_status.is_full;
            valid_o_2 = 1'b0;
        end else begin
            valid_o_1 = 1'b0;
            valid_o_2 = 1'b0;
        end
    end
    //Do new preg allocations
    assign do_alloc_1 = valid_o_1 & instr_a_rd_rename;
    assign do_alloc_2 = valid_o_2 & instr_b_rd_rename;

	//Free List
	assign fl_push = commit.valid_commit & (commit.ldst >7) & (commit.ldst <16);
	assign fl_data = commit.flushed ? commit.pdst : commit.ppdst;
	free_list #(
		.DATA_WIDTH (P_ADDR_WIDTH),
		.RAM_DEPTH  (16          ),
		.L_REGISTERS(L_REGISTERS )
	) free_list (
		.clk       (clk          ),
		.rst       (~rst_n       ),
		//Reclaim Interface
		.push_data (fl_data      ),
		.push      (fl_push      ),
		.ready     (fl_ready     ),
		//Alloc First Dest
		.pop_data_1(alloc_p_reg_1),
		.valid_1   (fl_valid_1   ),
		.pop_1     (do_alloc_1   ),
		//Alloc Second Dest
		.pop_data_2(alloc_p_reg_2),
		.valid_2   (fl_valid_2   ),
		.pop_2     (do_alloc_2   )
	);
	//RAT (DecodeRAT & CheckpointedRAT)
	logic       rat_alloc_1, rat_alloc_2, take_checkpoint, instr_num;
	logic [2:0] rat_allo_addr_1;

    assign rat_push        = commit.valid_commit & (commit.ldst >7) & (commit.ldst <16) & ~commit.flushed;
    assign rat_alloc_1     = (valid_o_1 & instr_a_rd_rename) | (valid_o_1 & valid_o_2 & ~instr_a_rd_rename & instr_b_rd_rename);
    assign rat_allo_addr_1 = instr_a_rd_rename ? instruction_1.destination[2:0] : instruction_2.destination[2:0];
    assign rat_alloc_2     = (valid_o_1 & valid_o_2 & instr_a_rd_rename & instr_b_rd_rename);

    assign take_checkpoint = (instruction_1.is_branch & valid_i_1 & valid_o_1) | (instruction_2.is_branch & valid_i_2 & valid_o_2);
    assign dual_branch     = (instruction_1.is_branch & valid_i_1) & (instruction_2.is_branch & valid_i_2);
    assign instr_num       = instruction_2.is_branch;

    rat #(
        .P_ADDR_WIDTH(P_ADDR_WIDTH),
        .L_ADDR_WIDTH($clog2(8)   ),
        .C_NUM       (C_NUM       )
    ) rat (
        .clk            (clk                           ),
        .rst_n          (rst_n                         ),

        .write_en_1     (rat_alloc_1                   ),
        .write_addr_1   (rat_allo_addr_1               ),
        .write_data_1   (alloc_p_reg_1                 ),
        .instr_1_rn     (instr_a_rd_rename             ),

        .write_en_2     (rat_alloc_2                   ),
        .write_addr_2   (instruction_2.destination[2:0]),
        .write_data_2   (alloc_p_reg_2                 ),

        .read_addr_1    (instruction_1.source1[2:0]    ),
        .read_data_1    (instr1_source1_rat            ),

        .read_addr_2    (instruction_1.source2[2:0]    ),
        .read_data_2    (instr1_source2_rat            ),

        .read_addr_3    (instruction_1.source3[2:0]    ),
        .read_data_3    (instr1_source3_rat            ),

        .read_addr_4    (instruction_2.source1[2:0]    ),
        .read_data_4    (instr2_source1_rat            ),

        .read_addr_5    (instruction_2.source2[2:0]    ),
        .read_data_5    (instr2_source2_rat            ),

        .read_addr_6    (instruction_2.source3[2:0]    ),
        .read_data_6    (instr2_source3_rat            ),

        .read_addr_7    (instruction_1.destination[2:0]),
        .read_data_7    (ppreg_1                       ),

        .read_addr_8    (instruction_2.destination[2:0]),
        .read_data_8    (ppreg_2                       ),

        .take_checkpoint(take_checkpoint               ),
        .instr_num      (instr_num                     ),
        .dual_branch    (dual_branch                   ),
        .current_id     (current_id                    ),

        .restore_rat    (flush_valid                   ),
        .restore_id     (flush_rat_id                  )
    );




`ifdef INCLUDE_SVAS
    `include "rr_sva.sv"
`endif

endmodule