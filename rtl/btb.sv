/*
* @info Brach Target Buffer
* @info Top Modules: Predictor.sv
*
* @author VLSI Lab, EE dept., Democritus University of Thrace
*
* @brief A target predictor, addressable with the PC address, for use in dynamic predictors
*
* @note The SRAM Stores in each entry: [OriginatingPC/TargetPC]
*
* @param PC_BITS       : # of PC Address Bits
* @param SEL_BITS      : # of Selector bits used from PC
* @param SIZE          : # of addressable entries (lines) in the array
*/
module btb #(PC_BITS=32,SIZE=1024) (
    input  logic               clk       ,
    input  logic               rst_n     ,
    //Update Interface
    input  logic               wr_en     ,
    input  logic [PC_BITS-1:0] orig_pc   ,
    input  logic [PC_BITS-1:0] target_pc ,
    //Invalidation Interface
    input  logic               invalidate,
    input  logic [PC_BITS-1:0] pc_invalid,
    //Access Interface
    input  logic [PC_BITS-1:0] pc_in     ,
    output logic               hit       ,
    output logic [PC_BITS-1:0] next_pc
);
  localparam SEL_BITS = $clog2(SIZE);
	// #Internal Signals#
    logic [SEL_BITS-1 : 0] line_selector, line_write_selector, line_inv_selector;
    logic [ 2*PC_BITS-1:0] retrieved_data, new_data;
    logic [      SIZE-1:0] validity      ;
    logic                  masked_wr_en  ;
  localparam int BTB_SIZE = SIZE*2*PC_BITS + $bits(validity);
	//create the line selector from the pc_in bits k-2
	assign line_selector       = pc_in[SEL_BITS : 1];
	//Create the line selector for the write operation
	assign line_write_selector = orig_pc[SEL_BITS : 1];
	//Create the new Data to be stored ([orig_pc/target_pc])
	assign new_data            = { orig_pc,target_pc };
	//Create the Invalidation line selector
	assign line_inv_selector   = pc_invalid[SEL_BITS : 1];

    sram #(.SIZE        (SIZE),
           .DATA_WIDTH  (2*PC_BITS),
           .RD_PORTS    (1),
           .WR_PORTS    (1),
           .RESETABLE   (0))
    SRAM (.clk                 (clk),
          .rst_n               (rst_n),
          .wr_en               (wr_en),
          .read_address        (line_selector),
          .data_out            (retrieved_data),
          .write_address       (line_write_selector),
          .new_data            (new_data));

    //always output the target PC
	assign next_pc = retrieved_data[0 +: PC_BITS];

	always_comb begin : HitOutput
		//Calculate hit signal
		if (retrieved_data[PC_BITS +: PC_BITS]==pc_in) begin
			hit = validity[line_selector];
		end else begin
			hit = 0;
		end
	end

    assign masked_wr_en = invalidate ? wr_en & (line_inv_selector!=line_write_selector) : wr_en;
	always_ff @(posedge clk or negedge rst_n) begin : ValidityBits
		if(!rst_n) begin
			 validity[SIZE-1:0] <= 'd0;
		end else begin
			 if(invalidate) begin
			 	validity[line_inv_selector] <= 0;
			 end
             if(masked_wr_en) begin
			 	validity[line_write_selector] <= 1;
			 end
		end
	end

endmodule