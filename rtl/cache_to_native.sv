`ifdef MODEL_TECH
    `include "structs.sv"
`endif
module cache_to_native #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 256
)(
  input  logic clk,
  input  logic resetn,

  // L1$ side
  input  logic                  cache_write_valid,
  input  logic [ADDR_WIDTH-1:0] cache_write_addr,
  input  logic [DATA_WIDTH-1:0] cache_write_data,
  input  logic                  cache_read_valid,
  input  logic [ADDR_WIDTH-1:0] cache_read_addr,
  output logic                  cache_update_valid,
  output logic [ADDR_WIDTH-1:0] cache_update_addr,
  output logic [DATA_WIDTH-1:0] cache_update_data,

  // Valid-Ready Native
  output logic                  nat_request_valid,
  input  logic                  nat_request_ready,
  output logic [           1:0] nat_request_op,
  output logic [ADDR_WIDTH-1:0] nat_request_addr,
  output logic [DATA_WIDTH-1:0] nat_request_data,
  input  logic                  nat_update_valid,
  output logic                  nat_update_ready,
  input  logic [DATA_WIDTH-1:0] nat_update_data
);

// FIFOs' signals
logic [DATA_WIDTH+ADDR_WIDTH-1:0] wf_data_out;
logic wf_ready, wf_valid, wf_pop;
logic [ADDR_WIDTH-1:0] rf_data_out;
logic rf_ready, rf_valid, rf_pop;
logic req_push, req_pop, req_ready, req_valid;
logic [DATA_WIDTH+ADDR_WIDTH:0] req_data_in, req_data_out;
logic upd_push, upd_pop, upd_ready, upd_valid;
logic [DATA_WIDTH+ADDR_WIDTH-1:0] upd_data_in, upd_data_out;  
// aligns address to 4 bytes
logic [31:0] mask;
assign mask = 32'hffffffe0;
// stores address in case of reads
logic addr_keep_flag;
logic [ADDR_WIDTH-1:0] address_keep;
// pseudo-arbitration
logic pri_flag;


always_ff @(posedge clk) begin
  if (!resetn) begin
    pri_flag <= 0;
  end else begin
    pri_flag <= ~pri_flag;
  end
end

assign wf_pop = wf_valid & pri_flag;
simple_fifo #(
  .DATA_WIDTH (DATA_WIDTH+ADDR_WIDTH),
  .DEPTH      (4)
) write_fifo (
  .clk_i    (clk),
  .rst_ni   (resetn),
  .data_i   ({cache_write_addr, cache_write_data}),
  .push_i   (cache_write_valid),
  .ready_o  (wf_ready),
  .data_o   (wf_data_out),
  .valid_o  (wf_valid),
  .pop_i    (wf_pop),
  .usage_o  ()
);

assign rf_pop = rf_valid & ~pri_flag;
simple_fifo #(
  .DATA_WIDTH (ADDR_WIDTH),
  .DEPTH      (4)
) read_fifo (
  .clk_i    (clk),
  .rst_ni   (resetn),
  .data_i   (cache_read_addr),
  .push_i   (cache_read_valid),
  .ready_o  (rf_ready),
  .data_o   (rf_data_out),
  .valid_o  (rf_valid),
  .pop_i    (rf_pop),
  .usage_o  ()
);

assign req_push = wf_pop | rf_pop;
assign req_pop  = nat_request_valid & nat_request_ready;
assign req_data_in[DATA_WIDTH+ADDR_WIDTH]               = (wf_pop) ? 1                                               : (rf_pop) ? 0           : 0;
assign req_data_in[DATA_WIDTH+ADDR_WIDTH-1:DATA_WIDTH]  = (wf_pop) ? wf_data_out[DATA_WIDTH+ADDR_WIDTH-1:DATA_WIDTH] : (rf_pop) ? rf_data_out : rf_data_out;
assign req_data_in[DATA_WIDTH-1:0]                      = (wf_pop) ? wf_data_out[DATA_WIDTH-1:0]                     : (rf_pop) ? 0           : 0;
simple_fifo #(
  .DATA_WIDTH (DATA_WIDTH+ADDR_WIDTH+1),
  .DEPTH      (4)
) request_fifo (
  .clk_i    (clk),
  .rst_ni   (resetn),
  .data_i   (req_data_in),
  .push_i   (req_push),
  .ready_o  (req_ready),
  .data_o   (req_data_out),
  .valid_o  (req_valid),
  .pop_i    (req_pop),
  .usage_o  ()
);

always_comb begin : axi
  if (req_valid) begin
    if (req_data_out[DATA_WIDTH+ADDR_WIDTH]) begin
      nat_request_op = 2'b10;
    end else begin
      nat_request_op = 2'b01;
    end
  end else begin
    nat_request_op = 2'b00;
  end
end

always_ff @( posedge clk ) begin
  if (!resetn)
    address_keep <= 0;
  else if (req_pop && nat_request_op[0])
    address_keep <= nat_request_addr;
end

always_ff @( posedge clk ) begin
  if (!resetn) 
    addr_keep_flag <= 0;
  else if (req_pop && nat_request_op[0]) 
    addr_keep_flag <= 1;
  else if (upd_push) 
    addr_keep_flag <= 0;
end

assign upd_push    = nat_update_valid & nat_update_ready;
assign upd_pop     = upd_valid;
assign upd_data_in = {nat_update_data, address_keep};

simple_fifo #(
  .DATA_WIDTH (DATA_WIDTH+ADDR_WIDTH),
  .DEPTH      (4)
) return_fifo (
  .clk_i    (clk),
  .rst_ni   (resetn),
  .data_i   (upd_data_in),
  .push_i   (upd_push),
  .ready_o  (upd_ready),
  .data_o   (upd_data_out),
  .valid_o  (upd_valid),
  .pop_i    (upd_pop),
  .usage_o  ()
);

assign nat_request_valid = req_valid & ~addr_keep_flag;
assign nat_request_addr  = req_data_out[DATA_WIDTH+ADDR_WIDTH-1:DATA_WIDTH] & mask;
assign nat_request_data  = req_data_out[DATA_WIDTH-1:0];
assign nat_update_ready  = upd_ready;

assign cache_update_valid = upd_valid;
assign cache_update_addr  = upd_data_out[ADDR_WIDTH-1:0];
assign cache_update_data  = upd_data_out[DATA_WIDTH+ADDR_WIDTH-1:ADDR_WIDTH];

endmodule