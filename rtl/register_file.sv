/*
* @info Register File Module
*
* @author VLSI Lab, EE dept., Democritus University of Thrace
*
* @brief The size and read ports can be parameterized.
*		 Only one write port
*        Regiter R0 is hardwired to value==0
*
* @param DATA_WIDTH : # of Data Bits
* @param ADDR_WIDTH : # of Address Bits
* @param SIZE       : # of Entries in the Register File
* @param READ_PORTS : # of Read Ports
*/
module register_file
	#(DATA_WIDTH=32, ADDR_WIDTH=6, SIZE=64, READ_PORTS=2)(
	input  logic                                  clk       ,
	input  logic                                  rst_n     ,
	input  logic                                  write_en  ,
	// Write Port
	input  logic [ADDR_WIDTH-1:0]                 write_addr,
	input  logic [DATA_WIDTH-1:0]                 write_data,
	// Read Port
	input  logic [READ_PORTS-1:0][ADDR_WIDTH-1:0] read_addr ,
	output logic [READ_PORTS-1:0][DATA_WIDTH-1:0] data_out
);
	// #Internal Signals#
	logic [SIZE-1:0][DATA_WIDTH-1 : 0] RegFile;
	logic not_zero;

	//do not write on slot 0
	assign not_zero = |write_addr;
	//Write Data
	always_ff @(posedge clk or negedge rst_n) begin : WriteData
		if(!rst_n) begin
			RegFile[0] <= 'b0;
		end else begin
			if(write_en && not_zero) begin
				RegFile[write_addr] <= write_data;
			end
		end
	end
	//Output Data
	always_comb begin : ReadData
		for (int i = 0; i < READ_PORTS; i++) begin
			data_out[i] = RegFile[read_addr[i]];
		end
	end

endmodule