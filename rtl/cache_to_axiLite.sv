import structs::*;

module proc_to_axiLite # (
  parameter ADDR_BITS     = 32,  // default: 32
  parameter DATA_WIDTH    = 32,  // default: 32
  parameter R_WIDTH       = 6,   // default: 6
  parameter MICROOP_W     = 5,   // default: 5
  parameter ROB_ENTRIES   = 8,   // default: 8
  localparam ROB_TICKET_W = $clog2(ROB_ENTRIES), //default: DO NOT MODIFY
  parameter RESP_WIDTH    = 2    // default: 2
)(
  input logic clk,
  input logic resetn,

  input  logic                    master_ready,
  
  input  logic                    write_valid,
  input  logic [ADDR_BITS-1:0]    w_addr,
  input  logic [DATA_WIDTH-1:0]   w_data,
  
  input  logic                    read_valid,
  input  logic [ADDR_BITS-1:0]    r_addr,
  input  logic [R_WIDTH-1:0]      r_dest,
  input  logic [MICROOP_W-1:0]    r_microop,
  input  logic [ROB_TICKET_W-1:0] r_ticket,

  output ex_update                read_response,

  output  logic                   axi_awvalid,
  input   logic                   axi_awready,
  output  logic [ADDR_BITS-1:0]   axi_awaddr,
  output  logic                   axi_wvalid,
  input   logic                   axi_wready,
  output  logic [DATA_WIDTH-1:0]  axi_wdata,
  input   logic                   axi_bvalid,
  output  logic                   axi_bready,
  input   logic [RESP_WIDTH-1:0]  axi_bresp,
  output  logic                   axi_arvalid,
  input   logic                   axi_arready,
  output  logic [ADDR_BITS-1:0]   axi_araddr,
  input   logic                   axi_rvalid,
  output  logic                   axi_rready,
  input   logic [DATA_WIDTH-1:0]  axi_rdata,
  input   logic [RESP_WIDTH-1:0]  axi_rresp  
);


  logic o_full, o_empty, o_pop;
  logic [1:0] o_data_in, o_data_out;
  logic w_full, w_empty, w_pop;
  logic [DATA_WIDTH+ADDR_BITS-1:0] w_data_out;
  logic r_full, r_empty, r_pop;
  logic [ADDR_BITS-1:0] r_data_out;
  logic pend;
  logic reg_full, reg_empty, reg_pop;
  logic [R_WIDTH+MICROOP_W+ROB_TICKET_W-1:0] reg_data_out;
  logic ret_full, ret_empty, ret_pop;
  logic [DATA_WIDTH-1:0] ret_data_out;


  assign o_data_in = (write_valid) ? 'd1 : (read_valid) ? 'd2 : 0;
  assign o_pop = w_pop | r_pop;

   fifo # (
    .DATA_WIDTH(2),
    .DEPTH(8)
   ) order_fifo (
    .clk      (clk        ),
    .resetn   (resetn     ),
    .data_in  (o_data_in  ),
    .push     (write_valid | read_valid),
    .full     (o_full     ),
    .data_out (o_data_out ),
    .empty    (o_empty    ),
    .pop      (o_pop      )
  );


  assign w_pop = axi_awvalid & axi_awready;

  fifo # (
    .DATA_WIDTH(DATA_WIDTH+ADDR_BITS),
    .DEPTH(4)
  ) write_fifo (
    .clk      (clk             ),
    .resetn   (resetn          ),
    .data_in  ({w_data, w_addr}),
    .push     (write_valid     ),
    .full     (w_full          ),
    .data_out (w_data_out      ),
    .empty    (w_empty         ),
    .pop      (w_pop           )
  );


  assign r_pop = axi_arvalid & axi_arready;

  fifo # (
    .DATA_WIDTH(ADDR_BITS),
    .DEPTH(4)
  ) read_a_fifo (
    .clk      (clk        ),
    .resetn   (resetn     ),
    .data_in  (r_addr     ),
    .push     (read_valid ),
    .full     (r_full     ),
    .data_out (r_data_out ),
    .empty    (r_empty    ),
    .pop      (r_pop      )
  );
  
  always_ff @( posedge clk ) begin
    if (!resetn) begin
      axi_arvalid <= 0;
    end else if (axi_arvalid && axi_arready) begin
      axi_arvalid <= 0;
    end else if (!r_empty && !pend && o_data_out == 'd2) begin
      axi_arvalid <= 1;
    end
  end

  always_ff @( posedge clk ) begin
    if (!resetn) begin
      pend <= 0;
    end else if (axi_arvalid && axi_arready) begin
      pend <= 1;
    end else if (axi_rvalid && axi_rready) begin
      pend <= 0;    
    end
  end


  assign reg_pop = ~ret_empty;

  fifo # (
    .DATA_WIDTH(R_WIDTH+MICROOP_W+ROB_TICKET_W),
    .DEPTH(4)
  ) read_reg_fifo (
    .clk      (clk          ),
    .resetn   (resetn       ),
    .data_in  ({r_dest, r_microop, r_ticket}),
    .push     (read_valid   ),
    .full     (reg_full     ),
    .data_out (reg_data_out ),
    .empty    (reg_empty    ),
    .pop      (reg_pop      )
  );

  assign ret_pop = ~ret_empty;

  fifo # (
    .DATA_WIDTH(DATA_WIDTH),
    .DEPTH(4)
  ) return_fifo (
    .clk      (clk        ),
    .resetn   (resetn     ),
    .data_in  (axi_rdata  ),
    .push     (axi_rvalid && axi_rready),
    .full     (ret_full     ),
    .data_out (ret_data_out ),
    .empty    (ret_empty    ),
    .pop      (ret_pop      )
  );


  
  assign axi_awvalid = ~w_empty & o_data_out == 'd1;
  assign axi_awaddr  = w_data_out[ADDR_BITS-1:0];
  assign axi_wvalid  = ~w_empty & o_data_out == 'd1;
  assign axi_wdata   = w_data_out[DATA_WIDTH+ADDR_BITS-1:ADDR_BITS];
  assign axi_bready  = 1;
  assign axi_araddr  = r_data_out;
  assign axi_rready  = master_ready;

  assign read_response.valid            = ret_pop;
  assign read_response.destination      = reg_data_out[R_WIDTH+MICROOP_W+ROB_TICKET_W-1:MICROOP_W+ROB_TICKET_W];
  assign read_response.ticket           = reg_data_out[ROB_TICKET_W-1:0];
  assign read_response.data             = ret_data_out;
  assign read_response.valid_exception  = 0;
  assign read_response.cause            = 4'b0;

endmodule