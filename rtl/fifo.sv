module fifo #(
    parameter  DATA_WIDTH  = 32,
    parameter  DEPTH       = 16,
    localparam INDEX_WIDTH = (DEPTH>1) ? $clog2(DEPTH) : 1
)(
    input logic clk, 
    input logic resetn,
    input  logic[DATA_WIDTH-1:0] data_in,
    input  logic                 push,
    output logic                 full,
    output logic[DATA_WIDTH-1:0] data_out,
    output logic                 empty,
    input  logic                 pop
);
    
logic [DATA_WIDTH-1:0] fifo_data [DEPTH];
logic [INDEX_WIDTH:0] head;
logic [INDEX_WIDTH:0] tail;
logic [INDEX_WIDTH:0] items;

assign empty = (items==0);
assign full = (items==DEPTH);

always_ff @(posedge clk) begin
    if (!resetn) begin
        items <= 0;
    end else begin
        if (push && ~pop && !full) begin
            items <= items +1;
        end else if (~push && pop && !empty) begin
            items <= items - 1;
        end
    end
end

always_ff @(posedge clk) begin
    if (!resetn) begin 
        tail <= 0;
    end else begin
        if (push && (pop || !full)) begin
            if (tail == DEPTH-1) begin
                tail <= 0;
            end else begin
                tail <= tail + 1;
            end
        end
    end
end

always_ff @(posedge clk) begin
    if (!resetn) begin
        head <= 0;
    end else begin
        if (pop && !empty) begin
            if (head == DEPTH-1) begin
                head <= 0;
            end else begin
                head <= head + 1;
            end
        end
    end
end

always_ff @ (posedge clk) begin
    if (!resetn) begin
        for (int i=0; i<DEPTH; i++) begin
            fifo_data[i] <= '{default: 'd0};
        end
    end else if (push && (pop || !full)) begin
        fifo_data[tail] <= data_in;
    end
end

assign data_out = fifo_data[head];

endmodule