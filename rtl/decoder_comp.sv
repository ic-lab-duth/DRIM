/*
* @info Decoder for Compressed Instructions (16-bit instr)
*
* @author VLSI Lab, EE dept., Democritus University of Thrace
*
* @note Functional Units:
* 00 : Load/Store Unit
* 01 : Floating Point Unit
* 10 : Integer Unit
* 11 : Branches
*
* @param INSTR_BITS: # of Instruction Bits (default 16 bits)
* @param PC_BITS   : # of PC Bits (default 32 bits)
*/
// `include "enum.sv"
`ifdef MODEL_TECH
    `include "structs.sv"
`endif
module decoder_comp #(INSTR_BITS = 16, PC_BITS=32) (
    input  logic                  clk           ,
    input  logic                  rst_n         ,
    //Input Port
    input  logic                  valid         ,
    input  logic [   PC_BITS-1:0] pc_in         ,
    input  logic [INSTR_BITS-1:0] instruction_in,
    //Output Port
    output decoded_instr          outputs       ,
    output logic                  is_return     ,
    output logic                  valid_branch
);

    // #Internal Signals#
    // detected_instr_c         detected_instr;
    logic                    valid_map, is_branch;
    logic            [1 : 0] opcode, temp, temp_2;
    logic            [2 : 0] funct3, rdc, source1c, source2c;
    logic            [3 : 0] funct4        ;
    logic            [4 : 0] source1, source2, rd, temp_3;

    assign valid_branch    = is_branch & valid;
    //Create Output
    assign outputs.pc      = pc_in;
    assign outputs.is_valid= valid_map & valid;

	//Grab Fields from the Instruction
	assign source1  = instruction_in[11:7];
	assign source1c = instruction_in[9:7];

	assign source2  = instruction_in[6:2];
	assign source2c = instruction_in[4:2];

	assign rd  = instruction_in[11:7];
	assign rdc = instruction_in[4:2];

	assign outputs.source3 = 'b0;
	assign outputs.rm = 'b0;

	assign opcode = instruction_in[1:0];
	assign funct3 = instruction_in[15:13];
	assign funct4 = instruction_in[15:12];

    assign temp   = instruction_in[11:10];
    assign temp_2 = instruction_in[6:5];
    assign temp_3 = instruction_in[6:2];

    assign is_return = (opcode==2'b10) & (funct3==3'b100) & (funct4==4'b1000)& (source1==1) & (source2==0);
    //Decode the Instruction
    assign outputs.is_branch = is_branch;
	always_comb begin : OPCcheck
		valid_map = 1'b0;
        outputs.source1 = 'b0;
        outputs.source1_pc = 'b0;
        outputs.source2 = 'b0;
        outputs.source2_immediate = 'b0;
        outputs.destination = 'b0;
        outputs.immediate = 'b0;
        outputs.functional_unit = 'b0;
        outputs.microoperation = 'b0;
        is_branch = 1'b0;
		case (opcode)
			//LOAD ->
			2'b00:begin
                case (funct3)
                    3'b000: begin
                        //C.ADDI4SPN
                        outputs.source1 = {1'b0,5'b00010};
                        outputs.source1_pc = 1'b0;
                        outputs.source2 = 'b0;
                        outputs.source2_immediate = 1'b1;
                        outputs.destination = {2'b0,1'b1,rdc};
                        outputs.immediate = {{22{1'b0}},instruction_in[10:7],instruction_in[12:11],instruction_in[5],instruction_in[6],2'b00};
                        outputs.functional_unit = 2'b10;
                        outputs.microoperation = 5'b00000;
                        valid_map = 1'b1;
                        is_branch = 1'b0;
                        //detected_instr = CADDI4SPN;
                    end
                    // 3'b001: begin
                    //     //C.FLD
                    // end
                    3'b010: begin
                        //C.LW
                        outputs.source1 = {2'b0,1'b1,source1c};
                        outputs.source1_pc = 1'b0;
                        outputs.source2 = 'b0;
                        outputs.source2_immediate = 1'b1;
                        outputs.destination = {2'b0,1'b1,rdc};
                        outputs.immediate = {{25{1'b0}},instruction_in[5],instruction_in[12:10],instruction_in[6],2'b00};
                        outputs.functional_unit = 2'b00;
                        outputs.microoperation = 5'b00001;
                        valid_map = 1'b1;
                        is_branch = 1'b0;
                        //detected_instr = CLW;
                    end
                    3'b011: begin
                        //C.FLW
                        outputs.source1 = {2'b0,1'b1,source1c};
                        outputs.source1_pc = 1'b0;
                        outputs.source2 = 'b0;
                        outputs.source2_immediate = 1'b1;
                        outputs.destination = {1'b1,1'b0,1'b1,rdc};
                        outputs.immediate = {{25{1'b0}},instruction_in[5],instruction_in[12:10],instruction_in[6],2'b00};
                        outputs.functional_unit = 2'b00;
                        outputs.microoperation = 5'b00001;
                        valid_map = 1'b1;
                        is_branch = 1'b0;
                        //detected_instr = CFLW;
                    end
                    // 3'b100: begin
                    //     //Reserved
                    // end
                    // 3'b101: begin
                    //     //C.FSD
                    // end
                    3'b110: begin
                        //C.SW
                        outputs.source1 = {2'b0,1'b1,source1c};
                        outputs.source1_pc = 1'b0;
                        outputs.source2 = {2'b0,1'b1,source2c};
                        outputs.source2_immediate = 1'b0;
                        outputs.destination = 'b0;
                        outputs.immediate = {{25{1'b0}},instruction_in[5],instruction_in[12:10],instruction_in[6],2'b00};
                        outputs.functional_unit = 2'b00;
                        outputs.microoperation = 5'b00110;
                        valid_map = 1'b1;
                        is_branch = 1'b0;
                        //detected_instr = CSW;
                    end
                    3'b111: begin
                        //C.FSW
                        outputs.source1 = {2'b0,1'b1,source1c};
                        outputs.source1_pc = 1'b0;
                        outputs.source2 = {1'b1,1'b0,1'b1,source2c};
                        outputs.source2_immediate = 1'b0;
                        outputs.destination = 'b0;
                        outputs.immediate = {{25{1'b0}},instruction_in[5],instruction_in[12:10],instruction_in[6],2'b00};
                        outputs.functional_unit = 2'b00;
                        outputs.microoperation = 5'b00110;
                        valid_map = 1'b1;
                        is_branch = 1'b0;
                        //detected_instr = CFSW;
                    end
                    default : begin
                        outputs.source1 = 'b0;
                        outputs.source1_pc = 'b0;
                        outputs.source2 = 'b0;
                        outputs.source2_immediate = 'b0;
                        outputs.destination = 'b0;
                        outputs.immediate = 'b0;
                        outputs.functional_unit = 'b0;
                        outputs.microoperation = 'b0;
                        valid_map = 1'b0;
                        is_branch = 1'b0;
                        //detected_instr = CIDLE;
                    end
                endcase
			end
			2'b01:begin
                case (funct3)
                    3'b000: begin
                        //C.ADDI
                        outputs.source1 = {1'b0,rd};
                        outputs.source1_pc = 1'b0;
                        outputs.source2 = 'b0;
                        outputs.source2_immediate = 1'b1;
                        outputs.destination = {1'b0,rd};
                        outputs.immediate = {{26{instruction_in[12]}},instruction_in[12],instruction_in[6:2]};
                        outputs.functional_unit = 2'b10;
                        outputs.microoperation = 5'b00000;
                        valid_map = 1'b1;
                        is_branch = 1'b0;
                        //detected_instr = CADDI;
                    end
                    3'b001: begin
                        //C.JAL
                        outputs.source1 = 'b0;
                        outputs.source1_pc = 1'b1;
                        outputs.source2 = 'b0;
                        outputs.source2_immediate = 1'b1;
                        outputs.destination = 6'b000001;
                        outputs.immediate = {{20{instruction_in[12]}},instruction_in[12],instruction_in[8],instruction_in[10:9],instruction_in[6],instruction_in[7],instruction_in[2],instruction_in[11],instruction_in[5:3],1'b0};
                        outputs.functional_unit = 2'b11;
                        outputs.microoperation = 5'b10011;
                        valid_map = 1'b1;
                        is_branch = 1'b1;
                        //detected_instr = CJAL;
                    end
                    3'b010: begin
                        //C.LI
                        outputs.source1 = 'b0;
                        outputs.source1_pc = 1'b0;
                        outputs.source2 = 'b0;
                        outputs.source2_immediate = 1'b1;
                        outputs.destination = {1'b0,rd};
                        outputs.immediate = {{26{instruction_in[12]}},instruction_in[12],instruction_in[6:2]};
                        outputs.functional_unit = 2'b10;
                        outputs.microoperation = 5'b00000;
                        valid_map = 1'b1;
                        is_branch = 1'b0;
                        //detected_instr = CLI;
                    end
                    3'b011: begin
                        if(rd==5'b00010) begin
                            //C.ADDI16SP
                            outputs.source1 = {1'b0,rd};
                            outputs.source1_pc = 1'b0;
                            outputs.source2 = 'b0;
                            outputs.source2_immediate = 1'b1;
                            outputs.destination = {1'b0,rd};
                            outputs.immediate = {{22{instruction_in[12]}},instruction_in[12],instruction_in[4:3],instruction_in[5],instruction_in[2],instruction_in[6],{4'b0}};
                            outputs.functional_unit = 2'b10;
                            outputs.microoperation = 5'b00000;
                            valid_map = 1'b1;
                            is_branch = 1'b0;
                            //detected_instr = CADDI16SP;
                        end else begin
                            //C.LUI
                            outputs.source1 = 'b0;
                            outputs.source1_pc = 1'b0;
                            outputs.source2 = 'b0;
                            outputs.source2_immediate = 1'b1;
                            outputs.destination = {1'b0,rd};
                            outputs.immediate = {{14{instruction_in[12]}},instruction_in[12],instruction_in[6:2],{12{1'b0}}};
                            outputs.functional_unit = 2'b10;
                            outputs.microoperation = 5'b00000;
                            valid_map = 1'b1;
                            is_branch = 1'b0;
                            //detected_instr = CLUI;
                        end
                    end
                    3'b100: begin
                        //MISC-ALU
                        case (temp)
                            2'b00: begin
                                //C.SRLI
                                outputs.source1 = {2'b0,1'b1,source1c};
                                outputs.source1_pc = 1'b0;
                                outputs.source2 = 'b0;
                                outputs.source2_immediate = 1'b1;
                                outputs.destination = {2'b0,1'b1,source1c};
                                outputs.immediate = {{26{1'b0}},instruction_in[12],instruction_in[6:2]};
                                outputs.functional_unit = 2'b11;
                                outputs.microoperation = 5'b01000;
                                valid_map = 1'b1;
                                is_branch = 1'b0;
                                //detected_instr = CSRLI;
                            end
                            2'b01: begin
                                //C.SRAI
                                outputs.source1 = {2'b0,1'b1,source1c};
                                outputs.source1_pc = 1'b0;
                                outputs.source2 = 'b0;
                                outputs.source2_immediate = 1'b1;
                                outputs.destination = {2'b0,1'b1,source1c};
                                outputs.immediate = {{26{1'b0}},instruction_in[12],instruction_in[6:2]};
                                outputs.functional_unit = 2'b11;
                                outputs.microoperation = 5'b01001;
                                valid_map = 1'b1;
                                is_branch = 1'b0;
                                //detected_instr = CSRAI;
                            end
                            2'b10: begin
                                //C.ANDI
                                outputs.source1 = {2'b0,1'b1,source1c};
                                outputs.source1_pc = 1'b0;
                                outputs.source2 = 'b0;
                                outputs.source2_immediate = 1'b1;
                                outputs.destination = {2'b0,1'b1,source1c};
                                outputs.immediate = {{26{instruction_in[12]}},instruction_in[12],instruction_in[6:2]};
                                outputs.functional_unit = 2'b10;
                                outputs.microoperation = 5'b01010;
                                valid_map = 1'b1;
                                is_branch = 1'b0;
                                //detected_instr = CANDI;
                            end
                            2'b11: begin
                                case (temp_2)
                                    2'b00: begin
                                        //C.SUB
                                        outputs.source1 = {2'b0,1'b1,source1c};
                                        outputs.source1_pc = 1'b0;
                                        outputs.source2 = {2'b0,1'b1,source2c};
                                        outputs.source2_immediate = 1'b0;
                                        outputs.destination = {2'b0,1'b1,source1c};
                                        outputs.immediate = 'b0;
                                        outputs.functional_unit = 2'b10;
                                        outputs.microoperation = 5'b00001;
                                        valid_map = 1'b1;
                                        is_branch = 1'b0;
                                        //detected_instr = CSUB;
                                    end
                                    2'b01: begin
                                        //C.XOR
                                        outputs.source1 = {2'b0,1'b1,source1c};
                                        outputs.source1_pc = 1'b0;
                                        outputs.source2 = {2'b0,1'b1,source2c};
                                        outputs.source2_immediate = 1'b0;
                                        outputs.destination = {2'b0,1'b1,source1c};
                                        outputs.immediate = 'b0;
                                        outputs.functional_unit = 2'b11;
                                        outputs.microoperation = 5'b01100;
                                        valid_map = 1'b1;
                                        is_branch = 1'b0;
                                        //detected_instr = CXOR;
                                    end
                                    2'b10: begin
                                        //C.OR
                                        outputs.source1 = {2'b0,1'b1,source1c};
                                        outputs.source1_pc = 1'b0;
                                        outputs.source2 = {2'b0,1'b1,source2c};
                                        outputs.source2_immediate = 1'b0;
                                        // outputs.destination = {2'b0,1'b1,rdc};
                                        outputs.destination = {2'b0,1'b1,source1c};
                                        outputs.immediate = 'b0;
                                        outputs.functional_unit = 2'b10;
                                        outputs.microoperation = 5'b01011;
                                        valid_map = 1'b1;
                                        is_branch = 1'b0;
                                        //detected_instr = COR;
                                    end
                                    2'b11: begin
                                        //C.AND
                                        outputs.source1 = {2'b0,1'b1,source1c};
                                        outputs.source1_pc = 1'b0;
                                        outputs.source2 = {2'b0,1'b1,source2c};
                                        outputs.source2_immediate = 1'b0;
                                        outputs.destination = {2'b0,1'b1,source1c};
                                        outputs.immediate = 'b0;
                                        outputs.functional_unit = 2'b10;
                                        outputs.microoperation = 5'b01010;
                                        valid_map = 1'b1;
                                        is_branch = 1'b0;
                                        //detected_instr = CAND;
                                    end
                                    default : begin
                                        outputs.source1 = 'b0;
                                        outputs.source1_pc = 'b0;
                                        outputs.source2 = 'b0;
                                        outputs.source2_immediate = 'b0;
                                        outputs.destination = 'b0;
                                        outputs.immediate = 'b0;
                                        outputs.functional_unit = 'b0;
                                        outputs.microoperation = 'b0;
                                        valid_map = 1'b0;
                                        is_branch = 1'b0;
                                        //detected_instr = CIDLE;
                                    end
                                endcase
                            end
                            default : begin
                                outputs.source1 = 'b0;
                                outputs.source1_pc = 'b0;
                                outputs.source2 = 'b0;
                                outputs.source2_immediate = 'b0;
                                outputs.destination = 'b0;
                                outputs.immediate = 'b0;
                                outputs.functional_unit = 'b0;
                                outputs.microoperation = 'b0;
                                valid_map = 1'b0;
                                is_branch = 1'b0;
                                //detected_instr = CIDLE;
                            end
                        endcase
                    end
                    3'b101: begin
                        //C.J
                        outputs.source1 = 'b0;
                        outputs.source1_pc = 1'b1;
                        outputs.source2 = 'b0;
                        outputs.source2_immediate = 1'b1;
                        outputs.destination = 'b0;
                        outputs.immediate = {{20{instruction_in[12]}},instruction_in[12],instruction_in[8],instruction_in[10:9],instruction_in[6],instruction_in[7],instruction_in[2],instruction_in[11],instruction_in[5:3],1'b0};
                        outputs.functional_unit = 2'b11;
                        outputs.microoperation = 5'b10011;
                        valid_map = 1'b1;
                        is_branch = 1'b1;
                        //detected_instr = CJ;
                    end
                    3'b110: begin
                        //C.BEQZ
                        outputs.source1 = {2'b0,1'b1,source1c};
                        outputs.source1_pc = 1'b0;
                        outputs.source2 = 'b0;
                        outputs.source2_immediate = 1'b0;
                        outputs.destination = 'b0;
                        outputs.immediate = {{23{instruction_in[12]}},instruction_in[12],instruction_in[6:5],instruction_in[2],instruction_in[11:10],instruction_in[4:3],1'b0};
                        outputs.functional_unit = 2'b11;
                        outputs.microoperation = 5'b10100;
                        valid_map = 1'b1;
                        is_branch = 1'b1;
                        //detected_instr = CBEQZ;
                    end
                    3'b111: begin
                        //C.BNEZ
                        outputs.source1 = {2'b0,1'b1,source1c};
                        outputs.source1_pc = 1'b0;
                        outputs.source2 = 'b0;
                        outputs.source2_immediate = 1'b0;
                        outputs.destination = 'b0;
                        outputs.immediate = {{23{instruction_in[12]}},instruction_in[12],instruction_in[6:5],instruction_in[2],instruction_in[11:10],instruction_in[4:3],1'b0};
                        outputs.functional_unit = 2'b11;
                        outputs.microoperation = 5'b10101;
                        valid_map = 1'b1;
                        is_branch = 1'b1;
                        //detected_instr = CBNEZ;
                    end
                    default : begin
                        outputs.source1 = 'b0;
                        outputs.source1_pc = 'b0;
                        outputs.source2 = 'b0;
                        outputs.source2_immediate = 'b0;
                        outputs.destination = 'b0;
                        outputs.immediate = 'b0;
                        outputs.functional_unit = 'b0;
                        outputs.microoperation = 'b0;
                        valid_map = 1'b0;
                        is_branch = 1'b0;
                        //detected_instr = CIDLE;
                    end
                endcase
			end
			2'b10:begin
                case (funct3)
                    3'b000: begin
                        //C.SLLI
                        outputs.source1 = {1'b0,rd};
                        outputs.source1_pc = 1'b0;
                        outputs.source2 = 'b0;
                        outputs.source2_immediate = 1'b1;
                        outputs.destination = {1'b0,rd};
                        outputs.immediate = {{26{1'b0}},instruction_in[12],instruction_in[6:2]};
                        outputs.functional_unit = 2'b11;
                        outputs.microoperation = 5'b00111;
                        valid_map = 1'b1;
                        is_branch = 1'b0;
                        //detected_instr = CSLLI;
                    end
                    // 3'b001: begin
                    //     //FLDSP
                    // end
                    3'b010: begin
                        //LWSP
                        outputs.source1 = {1'b0,5'b00010};
                        outputs.source1_pc = 1'b0;
                        outputs.source2 = 'b0;
                        outputs.source2_immediate = 1'b1;
                        outputs.destination = {1'b0,rd};
                        outputs.immediate = {{24{1'b0}},instruction_in[3:2],instruction_in[12],instruction_in[6:4],2'b00};
                        outputs.functional_unit = 2'b00;
                        outputs.microoperation = 5'b00001;
                        valid_map = 1'b1;
                        is_branch = 1'b0;
                        //detected_instr = CLWSP;
                    end
                    3'b011: begin
                        //FLWSP
                        outputs.source1 = {1'b0,5'b00010};
                        outputs.source1_pc = 1'b0;
                        outputs.source2 = 'b0;
                        outputs.source2_immediate = 1'b1;
                        outputs.destination = {1'b1,rd};
                        outputs.immediate = {{24{1'b0}},instruction_in[3:2],instruction_in[12],instruction_in[6:4],2'b00};
                        outputs.functional_unit = 2'b00;
                        outputs.microoperation = 5'b00001;
                        valid_map = 1'b1;
                        is_branch = 1'b0;
                        //detected_instr = CFLWSP;
                    end
                    3'b100: begin
                        //J[AL]R/MV/ADD
                        case (funct4)
                            4'b1000: begin
                                if(instruction_in[6:2]==5'b00000) begin
                                    //C.JR
                                    outputs.source1 = {1'b0,source1};
                                    outputs.source1_pc = 1'b0;
                                    outputs.source2 = 'b0;
                                    outputs.source2_immediate = 1'b0;
                                    outputs.destination = 'b0;
                                    outputs.immediate = 'b0;
                                    outputs.functional_unit = 2'b11;
                                    outputs.microoperation = 5'b10010;
                                    valid_map = 1'b1;
                                    is_branch = 1'b1;
                                    //detected_instr = CJR;
                                end else begin
                                    //C.MV
                                    outputs.source1 = 'b0;
                                    outputs.source1_pc = 1'b0;
                                    outputs.source2 = {1'b0,source2};
                                    outputs.source2_immediate = 1'b0;
                                    outputs.destination = {1'b0,rd};
                                    outputs.immediate = 'b0;
                                    outputs.functional_unit = 2'b10;
                                    outputs.microoperation = 5'b00000;
                                    valid_map = 1'b1;
                                    is_branch = 1'b0;
                                    //detected_instr = CMV;
                                end
                            end
                            4'b1001: begin
                                if(instruction_in[11:7]==5'b00000) begin
                                    //C.EBREAK
                                    outputs.source1 = 'b0;
                                    outputs.source1_pc = 'b0;
                                    outputs.source2 = 'b0;
                                    outputs.source2_immediate = 'b0;
                                    outputs.destination = 'b0;
                                    outputs.immediate = 'b0;
                                    outputs.functional_unit = 'b0;
                                    outputs.microoperation = 'b0;
                                    valid_map = 1'b0;
                                    is_branch = 1'b0;
                                    //detected_instr = CEBREAK;
                                end else if(instruction_in[6:2]==5'b00000) begin
                                    //C.JALR
                                    outputs.source1 = {1'b0,source1};
                                    outputs.source1_pc = 1'b0;
                                    outputs.source2 = 'b0;
                                    outputs.source2_immediate = 1'b0;
                                    outputs.destination = 6'b000001;
                                    outputs.immediate = 'b0;
                                    outputs.functional_unit = 2'b11;
                                    outputs.microoperation = 5'b10010;
                                    valid_map = 1'b1;
                                    is_branch = 1'b1;
                                    //detected_instr = CJALR;
                                end else begin
                                    //C.ADD
                                    outputs.source1 = {1'b0,rd};
                                    outputs.source1_pc = 1'b0;
                                    outputs.source2 = {1'b0,source2};
                                    outputs.source2_immediate = 1'b0;
                                    outputs.destination = {1'b0,rd};
                                    outputs.immediate = 'b0;
                                    outputs.functional_unit = 2'b10;
                                    outputs.microoperation = 5'b00000;
                                    valid_map = 1'b1;
                                    is_branch = 1'b0;
                                    //detected_instr = CADD;
                                end
                            end
                            default : begin
                                outputs.source1 = 'b0;
                                outputs.source1_pc = 'b0;
                                outputs.source2 = 'b0;
                                outputs.source2_immediate = 'b0;
                                outputs.destination = 'b0;
                                outputs.immediate = 'b0;
                                outputs.functional_unit = 'b0;
                                outputs.microoperation = 'b0;
                                valid_map = 1'b0;
                                is_branch = 1'b0;
                                //detected_instr = CIDLE;
                            end
                        endcase
                    end
                    3'b101: begin
                        //C.FSDSP
                    end
                    3'b110: begin
                        //C.SWSP
                        outputs.source1 = {1'b0,5'b00010};
                        outputs.source1_pc = 1'b0;
                        outputs.source2 = {1'b0,source2};
                        outputs.source2_immediate = 1'b0;
                        outputs.destination = 'b0;
                        outputs.immediate = {{24{1'b0}},instruction_in[8:7],instruction_in[12:9],2'b00};
                        outputs.functional_unit = 2'b00;
                        outputs.microoperation = 5'b00110;
                        valid_map = 1'b1;
                        is_branch = 1'b0;
                        //detected_instr = CSWSP;
                    end
                    3'b111: begin
                        //C.FSWSP
                        outputs.source1 = {1'b0,5'b00010};
                        outputs.source1_pc = 1'b0;
                        outputs.source2 = {1'b1,source2};
                        outputs.source2_immediate = 1'b0;
                        outputs.destination = 'b0;
                        outputs.immediate = {{24{1'b0}},instruction_in[8:7],instruction_in[12:9],2'b00};
                        outputs.functional_unit = 2'b00;
                        outputs.microoperation = 5'b00110;
                        valid_map = 1'b1;
                        is_branch = 1'b0;
                        //detected_instr = CFSWSP;
                    end
                    default : begin
                        outputs.source1 = 'b0;
                        outputs.source1_pc = 'b0;
                        outputs.source2 = 'b0;
                        outputs.source2_immediate = 'b0;
                        outputs.destination = 'b0;
                        outputs.immediate = 'b0;
                        outputs.functional_unit = 'b0;
                        outputs.microoperation = 'b0;
                        valid_map = 1'b0;
                        is_branch = 1'b0;
                        //detected_instr = CIDLE;
                    end
                endcase
			end
			default : begin
				outputs.source1 = 'b0;
				outputs.source1_pc = 'b0;
				outputs.source2 = 'b0;
				outputs.source2_immediate = 'b0;
				outputs.destination = 'b0;
				outputs.immediate = 'b0;
				outputs.functional_unit = 'b0;
				outputs.microoperation = 'b0;
				valid_map = 1'b0;
                is_branch = 1'b0;
                //detected_instr = CIDLE;
			end
		endcase
	end


endmodule