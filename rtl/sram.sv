// Copyright (c) 2024-2025 Integrated Circuits Lab, Democritus University of Thrace, Greece.
// 
// Copyright and related rights are licensed under the MIT License (the "License");
// you may not use this file except in compliance with the License. Unless required
// by applicable law or agreed to in writing, software, hardware and materials 
// distributed under this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
// OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Authors:
// - Ioannis Dingolis <ioanding@ee.duth.gr>

// A parametrizable memory module with asynchronous read ports and synchronous write ports.
// This memory module follows the RAM HDL Coding Guidelines (UG901) to be able to be 
// synthesized using memory primitives (distributed RAM) in an FPGA environment whenever possible.

module sram #(
    // Quantity of memory entries
    parameter int unsigned SIZE         = 0,
    // Width of each memory entry
    parameter int unsigned DATA_WIDTH   = 0,
    // Number of asynchronous read ports
    parameter int unsigned RD_PORTS     = 0,
    // Number of synchronous write ports
    parameter int unsigned WR_PORTS     = 0,
    // Is the memory asynchronously resettable?
    parameter bit          RESETABLE   = 0
) (
    input  logic                                  clk          ,
    input  logic                                  rst_n        ,
    //Write Port
    input  logic [WR_PORTS-1:0]                   wr_en        ,
    input  logic [WR_PORTS-1:0][$clog2(SIZE)-1:0] write_address,
    input  logic [WR_PORTS-1:0][  DATA_WIDTH-1:0] new_data     ,
    //Read Port
    input  logic [RD_PORTS-1:0][$clog2(SIZE)-1:0] read_address ,
    output logic [RD_PORTS-1:0][  DATA_WIDTH-1:0] data_out
);

    (* ram_style = "auto" *) logic [DATA_WIDTH-1:0] ram [SIZE-1:0];

    generate
        always_comb begin : asynchronous_read
            for (int i = 0; i < RD_PORTS; i++) begin
                data_out[i] = ram[read_address[i]];
            end
        end
    endgenerate

    generate
        if (RESETABLE) begin
            always_ff @( posedge clk or negedge rst_n ) begin : async_reset_sync_write
                if (!rst_n) begin
                    for (int i = 0; i < SIZE; i++) begin
                        ram[i] <= '0;
                    end
                end else begin
                    for (int i = 0; i < WR_PORTS; i++) begin
                        if (wr_en[i]) begin
                            ram[write_address[i]] <= new_data[i];
                        end
                    end
                end
            end
        end else begin
            always_ff @( posedge clk ) begin : synchronous_write
                for (int i = 0; i < WR_PORTS; i++) begin
                    if (wr_en[i]) begin
                        ram[write_address[i]] <= new_data[i];
                    end
                end
            end
        end
    endgenerate
endmodule
