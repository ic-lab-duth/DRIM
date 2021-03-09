/*
* @info GShare Predictor
* @info Top Modules: Predictor.sv
*
* @author VLSI Lab, EE dept., Democritus University of Thrace
*
* @brief A direction predictor, using the global history.
*
* @param PC_BITS 	   : # of PC Address Bits
* @param SEL_BITS 	   : # of Selector bits used from PC
* @param HISTORY_BITS : # of bits for Global History
* @param SIZE 		   : # of addressable entries (lines) in the array
*/
module gshare #(PC_BITS=32,HISTORY_BITS=2,SIZE=1024)
	(
	input  logic               clk         ,
	input  logic               rst_n       ,
	//Access Interface
	input  logic [PC_BITS-1:0] pc_in       ,
	output logic               is_taken_out,
	//Update Interface
	input  logic               wr_en       ,
	input  logic [PC_BITS-1:0] orig_pc     ,
	input  logic               is_taken
);
	localparam SEL_BITS = $clog2(SIZE);
	// #Internal Signals#
	logic [    SEL_BITS-1 : 0] line_selector    ;
	logic [HISTORY_BITS-1 : 0] counter_selector ;
	logic [HISTORY_BITS-1 : 0] gl_history       ;
	logic [             1 : 0] retrieved_counter, old_counter, final_value;
	logic [              7 :0] retrieved_data, write_retrieved_data, new_counter_vector;

	logic [    SEL_BITS-1 : 0] write_line_selector   ;
	logic [HISTORY_BITS-1 : 0] write_counter_selector;
	logic [HISTORY_BITS +1: 0] starting_bit, write_counter_stating_bit;
	logic [1:0][SEL_BITS-1 : 0]read_addresses;
	logic [1:0][7 :0] 		   data_out;

	localparam int GS_SIZE = 8*SIZE + $bits(gl_history);
	//create the Line Selector from the pc_in bits k-2
	assign line_selector = pc_in[SEL_BITS : 1];
	//create the Counter Selector (PC XOR global history)
	assign counter_selector = gl_history ^ pc_in[HISTORY_BITS : 1];
	//Pick one of the Counters
	assign starting_bit      = counter_selector << 1;
	assign retrieved_counter = retrieved_data[starting_bit +: 2];
	//MSB of counter is our output
	assign is_taken_out = retrieved_counter[1];

	assign read_addresses[0] = line_selector;
	assign read_addresses[1] = write_line_selector;

	sram #(
		.SIZE      (SIZE),
		.DATA_WIDTH(8   ),
		.RD_PORTS  (2   ),
		.WR_PORTS  (1   ),
		.RESETABLE (1   )
	) SRAM (
		.clk          (clk                ),
		.rst_n        (rst_n              ),
		.wr_en        (wr_en              ),
		.read_address (read_addresses     ),
		.data_out     (data_out           ),
		.write_address(write_line_selector),
		.new_data     (new_counter_vector )
	);

	assign retrieved_data       = data_out[0];
	assign write_retrieved_data = data_out[1];

	assign write_line_selector       = orig_pc[SEL_BITS : 1];
	assign write_counter_selector    = gl_history ^ orig_pc[HISTORY_BITS : 1];
	assign write_counter_stating_bit = write_counter_selector << 1;
	//Get the old Counter Value
	assign old_counter = write_retrieved_data[write_counter_stating_bit +: 2];
	//Calculate the next Counter Value (Increment/Decrement)
	always_comb begin : NewValue
		if(is_taken) begin
			if(old_counter<2'b11) begin
				final_value = old_counter+1;
			end else begin
				final_value = old_counter;
			end
		end else begin
			if(old_counter>2'b00) begin
				final_value = old_counter-1;
			end else begin
				final_value = old_counter;
			end
		end
	end
	//Create the vector to be written back
	always_comb begin : NewVector
		// Only one counter is modified
		new_counter_vector                               = write_retrieved_data;
		new_counter_vector[write_counter_stating_bit+:2] = final_value;
	end

	always_ff @(posedge clk or negedge rst_n) begin : UpdateGH
		//reset global history
		if(!rst_n) begin
			gl_history <= 2'b00;
		end else begin
			//Update Global History by sliding
			if(wr_en) begin
				gl_history <= { is_taken , gl_history[HISTORY_BITS-1:1] };
			end
		end
	end

endmodule