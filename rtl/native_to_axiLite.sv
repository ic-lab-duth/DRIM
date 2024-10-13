import structs::*;

module native_to_axiLite # (
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


  logic o_ready, o_valid, o_pop;
  logic [1:0] o_data_in, o_data_out;
  logic w_ready, w_valid, w_pop;
  logic [DATA_WIDTH+ADDR_BITS-1:0] w_data_out;
  logic r_ready, r_valid, r_pop;
  logic [ADDR_BITS-1:0] r_data_out;
  logic pend;
  logic reg_ready, reg_valid, reg_pop;
  logic [R_WIDTH+MICROOP_W+ROB_TICKET_W-1:0] reg_data_out;
  logic ret_ready, ret_valid, ret_pop;
  logic [DATA_WIDTH-1:0] ret_data_out;


  assign o_data_in = (write_valid) ? 'd1 : (read_valid) ? 'd2 : 0;
  assign o_pop = w_pop | r_pop;

   fifo_duth # (
    .DW(2),
    .DEPTH(8)
   ) order_fifo (
    .clk      (clk        ),
    .rst      (!resetn    ),
    .push_data(o_data_in  ),
    .push     (write_valid | read_valid),
    .ready    (o_ready    ),
    .pop_data (o_data_out ),
    .valid    (o_valid    ),
    .pop      (o_pop      )
  );


  assign w_pop = axi_awvalid & axi_awready;

  fifo_duth # (
    .DW(DATA_WIDTH+ADDR_BITS),
    .DEPTH(4)
  ) write_fifo (
    .clk      (clk             ),
    .rst      (!resetn         ),
    .push_data({w_data, w_addr}),
    .push     (write_valid     ),
    .ready    (w_ready         ),
    .pop_data (w_data_out      ),
    .valid    (w_valid         ),
    .pop      (w_pop           )
  );


  assign r_pop = axi_arvalid & axi_arready;

  fifo_duth # (
    .DW(ADDR_BITS),
    .DEPTH(4)
  ) read_a_fifo (
    .clk      (clk        ),
    .rst      (!resetn    ),
    .push_data(r_addr     ),
    .push     (read_valid ),
    .ready    (r_ready    ),
    .pop_data (r_data_out ),
    .valid    (r_valid    ),
    .pop      (r_pop      )
  );
  
  always_ff @( posedge clk ) begin
    if (!resetn) begin
      axi_arvalid <= 0;
    end else if (axi_arvalid && axi_arready) begin
      axi_arvalid <= 0;
    end else if (r_valid && !pend && o_data_out == 'd2) begin
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


  assign reg_pop = ret_valid;

  fifo_duth # (
    .DW(R_WIDTH+MICROOP_W+ROB_TICKET_W),
    .DEPTH(4)
  ) read_reg_fifo (
    .clk      (clk          ),
    .rst      (!resetn      ),
    .push_data({r_dest, r_microop, r_ticket}),
    .push     (read_valid   ),
    .ready    (reg_ready    ),
    .pop_data (reg_data_out ),
    .valid    (reg_valid    ),
    .pop      (reg_pop      )
  );

  assign ret_pop = ret_valid;

  fifo_duth # (
    .DW(DATA_WIDTH),
    .DEPTH(4)
  ) return_fifo (
    .clk      (clk        ),
    .rst      (!resetn    ),
    .push_data(axi_rdata  ),
    .push     (axi_rvalid && axi_rready),
    .ready    (ret_ready    ),
    .pop_data (ret_data_out ),
    .valid    (ret_valid    ),
    .pop      (ret_pop      )
  );


  
  assign axi_awvalid = w_valid & o_data_out == 'd1;
  assign axi_awaddr  = w_data_out[ADDR_BITS-1:0];
  assign axi_wvalid  = w_valid & o_data_out == 'd1;
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