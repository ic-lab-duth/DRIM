/*
* @info System Timers
*
* @author VLSI Lab, EE dept., Democritus University of Thrace
*
* @param DATA_WIDTH   : # of Data Bits (default 32 bits)
* @param ADDR_WIDTH   : # of Address Bits (default 6 bits) (OH)
* @param CYCLE_PERIOD : # ms for a clock cycle
*/
module status_counters #(
    parameter DATA_WIDTH   = 32,
    parameter ADDR_WIDTH   = 6 ,
    parameter CYCLE_PERIOD = 1
) (
    input  logic                  clk        ,
    input  logic                  rst_n      ,
    // input side
    input  logic [ADDR_WIDTH-1:0] read_addr_a,
    input  logic [ADDR_WIDTH-1:0] read_addr_b,
    input  logic                  valid_ret  ,
    //output side
    output logic [DATA_WIDTH-1:0] timer_out_a,
    output logic [DATA_WIDTH-1:0] timer_out_b
);
// ------------------------------------------------------------------------------------------------ //
    logic [ADDR_WIDTH-1:0][DATA_WIDTH-1:0] data_vector;
    logic [2*DATA_WIDTH-1:0] time_counter, cycle_counter, instr_counter;
// ------------------------------------------------------------------------------------------------ //
    //Time Counter
    always_ff @(posedge clk or negedge rst_n) begin : TimeCounter
        if(!rst_n) begin
            time_counter <= 0;
        end else begin
            time_counter <= (cycle_counter+1)*CYCLE_PERIOD;
        end
    end
    //Cycle Counter
    always_ff @(posedge clk or negedge rst_n) begin : CycleCounter
        if(!rst_n) begin
            cycle_counter <= 0;
        end else begin
            cycle_counter <= cycle_counter +1;
        end
    end
    //Instruction Counter
    always_ff @(posedge clk or negedge rst_n) begin : InstrCounter
        if(!rst_n) begin
            instr_counter <= 0;
        end else begin
            if (valid_ret) instr_counter <= instr_counter +1;
        end
    end
    //Intermidiate Signals
    assign data_vector[0] = cycle_counter[DATA_WIDTH-1:0];
    assign data_vector[1] = cycle_counter[2*DATA_WIDTH-1:DATA_WIDTH];
    assign data_vector[2] = time_counter[DATA_WIDTH-1:0];
    assign data_vector[3] = time_counter[2*DATA_WIDTH-1:DATA_WIDTH];
    assign data_vector[4] = instr_counter[DATA_WIDTH-1:0];
    assign data_vector[5] = instr_counter[2*DATA_WIDTH-1:DATA_WIDTH];
    //Pick the Outputs
    and_or_mux #(
        .INPUTS(ADDR_WIDTH),
        .DW    (DATA_WIDTH)
    ) mux_out_a (
        .data_in (data_vector),
        .sel     (read_addr_a),
        .data_out(timer_out_a)
    );

    and_or_mux #(
        .INPUTS(ADDR_WIDTH),
        .DW    (DATA_WIDTH)
    ) mux_out_b (
        .data_in (data_vector),
        .sel     (read_addr_b),
        .data_out(timer_out_b)
    );

endmodule
