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

// simple fifo with depth > 0 

module simple_fifo #(
    parameter int unsigned DEPTH = 0,
    parameter int unsigned DATA_WIDTH = 0,
    parameter int unsigned ADDR_DEPTH = (DEPTH > 1) ? $clog2(DEPTH) : 1
) (
    input logic clk_i,
    input logic rst_ni,
    input logic [DATA_WIDTH-1:0] data_i,
    input logic push_i,
    input logic pop_i,
    output logic [ADDR_DEPTH:0] usage_o,
    output logic ready_o,
    output logic valid_o,
    output logic [DATA_WIDTH-1:0] data_o
);
/*==================< FIFO Logic >==================*/
    logic [ADDR_DEPTH-1:0] read_pointer, write_pointer;
    logic [ADDR_DEPTH:0] status_counter;
    assign usage_o = status_counter;

    (* ram_style = "auto" *) logic [DATA_WIDTH-1:0] ram [DEPTH-1:0];

    always_ff @ ( posedge clk_i ) begin : synchronous_write
        if (push_i && ready_o) ram[write_pointer] <= data_i;
    end

    always_ff @( posedge clk_i or negedge rst_ni ) begin : fifo_seq
        if (!rst_ni) begin
            read_pointer <= '0;
            write_pointer <= '0;
            status_counter <= '0;
        end else begin
            if (push_i && ready_o) begin
                status_counter <= status_counter + 1;
                if (write_pointer == DEPTH - 1) begin           // if DEPTH != 2^n then set zero manually
                    write_pointer <= '0;                        // otherwise overflow
                end else begin
                    write_pointer <= write_pointer + 1;
                end
            end
            if (pop_i && valid_o) begin
                status_counter <= status_counter - 1;
                if (read_pointer == DEPTH - 1) begin
                    read_pointer <= '0;
                end else begin
                    read_pointer <= read_pointer + 1;
                end
            end
            if (push_i && ready_o && pop_i && valid_o) begin
                status_counter <= status_counter;               // Don't change counter.
            end

        end
    end

    always_comb begin : fifo_comb
        ready_o  = !(status_counter == DEPTH);
        valid_o = !(status_counter == 0);
        data_o = ram[read_pointer];
    end


    initial begin
        assert (DEPTH > 0) else $fatal("DEPTH must be greater than zero in simple_fifo.");
    end

    push_full: assert property(
        @( posedge clk_i ) disable iff (!rst_ni) (!ready_o |-> !push_i))
        else $fatal ("Pushing new data in simple_fifo while it's full.");

    pop_empty: assert property(
        @( posedge clk_i ) disable iff (!rst_ni) (!valid_o |-> !pop_i))
        else $fatal ("Popping data from simple_fifo while it's empty.");

    
endmodule