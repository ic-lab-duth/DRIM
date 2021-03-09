/*
 * @info Predictor Top-Module
 * @info Sub Modules: ras.sv  gshare.sv, btb.sv
 *
 * @author VLSI Lab, EE dept., Democritus University of Thrace
 *
 * @brief A dynamic Predictor, containing a gshare predictor for the direction prediction,
 * 		  a branch target buffer for the target prediction, and a return address stack
 *
 */
module predictor
	//Parameter List
	#(parameter int PC_BITS = 32,
	  parameter int RAS_DEPTH = 8,
	  parameter int GSH_HISTORY_BITS = 2,
	  parameter int GSH_SIZE = 256,
	  parameter int BTB_SIZE = 256)
	//Input List
	(input logic clk,
	 input logic rst_n,
	 //Control Interface
	 input logic 				  must_flush,
	 input logic 				  is_branch,
	 input logic 				  branch_resolved,
	 //Update Interface
	 input logic                  new_entry,
	 input logic [PC_BITS-1 : 0]  pc_orig,
	 input logic [PC_BITS-1 : 0]  target_pc,
	 input logic                  is_taken,
	 //RAS Interface
	 input logic                  is_return,
	 input logic                  is_jumpl,
	 input logic 			      invalidate,
	 input logic [PC_BITS-1 : 0]  old_pc,
	 //Access Interface
	 input logic [PC_BITS-1 : 0]  pc_in,
	 output logic				  taken_branch,
	 output logic [PC_BITS-1 : 0] next_pc);


	// #Internal Signals#
	logic [PC_BITS-1 : 0] next_pc_btb, pc_out_ras, new_entry_ras;
	logic hit, pop, push, is_empty_ras, is_taken_out;

	assign taken_branch = (hit & is_taken_out);
	//Initialize the GShare
	gshare #(
		.PC_BITS     (PC_BITS         ),
		.HISTORY_BITS(GSH_HISTORY_BITS),
		.SIZE        (GSH_SIZE        )
	) gshare (
		.clk         (clk         ),
		.rst_n       (rst_n       ),
		.pc_in       (pc_in       ),
		.is_taken_out(is_taken_out),
		.wr_en       (new_entry   ),
		.is_taken    (is_taken    ),
		.orig_pc     (pc_orig     )
	);
	//Initialize the BTB
	btb #(
		.PC_BITS(PC_BITS ),
		.SIZE   (BTB_SIZE)
	) btb (
		.clk       (clk        ),
		.rst_n     (rst_n      ),

		.pc_in     (pc_in      ),

		.wr_en     (new_entry  ),
		.orig_pc   (pc_orig    ),
		.target_pc (target_pc  ),

		.invalidate(invalidate ),
		.pc_invalid(old_pc     ),

		.hit       (hit        ),
		.next_pc   (next_pc_btb)
	);
	//Initialize the RAS
	ras #(
		.PC_BITS(PC_BITS  ),
		.SIZE   (RAS_DEPTH)
	) ras (
		.clk            (clk                  ),
		.rst_n          (rst_n                ),

		.must_flush     (must_flush           ),
		.is_branch      (is_branch & ~is_jumpl),
		.branch_resolved(branch_resolved      ),

		.pop            (pop                  ),
		.push           (push                 ),
		.new_entry      (new_entry_ras        ),
		.pc_out         (pc_out_ras           ),
		.is_empty       (is_empty_ras         )
	);

	//RAS Drive Signals
	assign pop  = (is_return & ~is_empty_ras);
	assign push = is_jumpl;
	assign new_entry_ras = old_pc +4;

	//push the Correct PC to the Output
	always_comb begin : PushOutput
		if(pop) begin
			next_pc = pc_out_ras;
		end else if(hit && is_taken_out) begin
			next_pc = next_pc_btb;
		end else begin
			next_pc = pc_in+4;
		end
	end

endmodule