`ifdef MODEL_TECH
    `include "structs.sv"
`endif
 
module cache_top #(
  parameter ADDR_BITS     = 32,  // default: 32
  parameter ISTR_DW       = 32,  // default: 32
  parameter DATA_WIDTH    = 32,  // default: 32
  parameter R_WIDTH       = 6,   // default: 6
  parameter MICROOP_W     = 5,   // default: 5
  parameter ROB_ENTRIES   = 8,   // default: 8
  localparam ROB_TICKET_W = $clog2(ROB_ENTRIES), //default: DO NOT MODIFY

  parameter ASSOCIATIVITY = 2,
  parameter IC_ENTRIES    = 32,
  parameter DC_ENTRIES    = 32,
  parameter IC_DW         = 256,
  parameter DC_DW         = 256,

  parameter USE_AXI    = 0,
  parameter AXI_AW     = 32,
  parameter AXI_DW     = 32
)(
  input logic clk,
  input logic resetn,

  // processor / instruction cache interface
  input  logic [ADDR_BITS-1:0]  icache_current_pc,
  output logic                  icache_hit_icache, 
  output logic                  icache_miss_icache, 
  output logic                  icache_half_fetch,
  output logic [ISTR_DW-1:0]    icache_instruction_out,

  // processor / data cache inteface
  input  logic                  dcache_output_used,

  input  logic                  dcache_load_valid,
  input  logic [ADDR_BITS-1:0]  dcache_load_address,
  input  logic [R_WIDTH-1:0]    dcache_load_dest,
  input  logic [MICROOP_W-1:0]  dcache_load_microop,
  input  logic [ROB_TICKET_W-1:0] dcache_load_ticket,

  input  logic                  dcache_store_valid,
  input  logic [ADDR_BITS-1:0]  dcache_store_address,
  input  logic [DATA_WIDTH-1:0] dcache_store_data,
  input  logic [MICROOP_W-1:0]  dcache_store_microop,

  output logic                  dcache_will_block,
  output logic                  dcache_blocked,
  output ex_update              dcache_served_output,

  // icache / L2 interface
  output logic                  valid_out,
  output logic [ADDR_BITS-1:0]  address_out,
  input  logic                  ready_in,
  input  logic [IC_DW-1:0]      data_in,

  // Request Write Port to L2
  output logic                  write_l2_valid,
  output logic [ADDR_BITS-1:0]  write_l2_addr,
  output logic [DC_DW-1 : 0]    write_l2_data,
  // Request Read Port to L2
  output logic                  request_l2_valid,
  output logic [ADDR_BITS-1:0]  request_l2_addr,
  // Update Port from L2
  input  logic                  update_l2_valid,
  input  logic [ADDR_BITS-1:0]  update_l2_addr,
  input  logic [DC_DW-1 : 0]    update_l2_data,


  // AXI interfaces
  output logic                  ic_m_axi_awvalid,
  input  logic                  ic_m_axi_awready,
  output logic [AXI_AW-1:0]     ic_m_axi_awaddr,
  output logic [1:0]             ic_m_axi_awburst,
  output logic [7:0]            ic_m_axi_awlen,
  output logic [2:0]            ic_m_axi_awsize,
  output logic [3:0]            ic_m_axi_awid,
  output logic                  ic_m_axi_wvalid,
  input  logic                  ic_m_axi_wready,
  output logic [AXI_DW-1:0]     ic_m_axi_wdata,
  output logic                  ic_m_axi_wlast,
  output logic [3:0]            ic_m_axi_wstrb,
  input  logic [3:0]            ic_m_axi_bid,
  input  logic [1:0]            ic_m_axi_bresp,
  input  logic                  ic_m_axi_bvalid,
  output logic                  ic_m_axi_bready,
  input  logic                  ic_m_axi_arready,
  output logic                  ic_m_axi_arvalid,
  output logic [AXI_AW-1:0]     ic_m_axi_araddr,
  output logic [1:0]             ic_m_axi_arburst,
  output logic [7:0]            ic_m_axi_arlen,
  output logic [2:0]            ic_m_axi_arsize,
  output logic [3:0]            ic_m_axi_arid,
  input  logic [AXI_DW-1:0]     ic_m_axi_rdata,
  input  logic                  ic_m_axi_rlast,
  input  logic [3:0]            ic_m_axi_rid,
  input  logic [1:0]            ic_m_axi_rresp,
  input  logic                  ic_m_axi_rvalid,
  output logic                  ic_m_axi_rready,

  output logic                  dc_m_axi_awvalid,
  input  logic                  dc_m_axi_awready,
  output logic [AXI_AW-1:0]     dc_m_axi_awaddr,
  output logic [1:0]             dc_m_axi_awburst,
  output logic [7:0]            dc_m_axi_awlen,
  output logic [2:0]            dc_m_axi_awsize,
  output logic [3:0]            dc_m_axi_awid,
  output logic                  dc_m_axi_wvalid,
  input  logic                  dc_m_axi_wready,
  output logic [AXI_DW-1:0]     dc_m_axi_wdata,
  output logic                  dc_m_axi_wlast,
  output logic [3:0]            dc_m_axi_wstrb,
  input  logic [3:0]            dc_m_axi_bid,
  input  logic [1:0]            dc_m_axi_bresp,
  input  logic                  dc_m_axi_bvalid,
  output logic                  dc_m_axi_bready,
  input  logic                  dc_m_axi_arready,
  output logic                  dc_m_axi_arvalid,
  output logic [AXI_AW-1:0]     dc_m_axi_araddr,
  output logic [1:0]             dc_m_axi_arburst,
  output logic [7:0]            dc_m_axi_arlen,
  output logic [2:0]            dc_m_axi_arsize,
  output logic [3:0]            dc_m_axi_arid,
  input  logic [AXI_DW-1:0]     dc_m_axi_rdata,
  input  logic                  dc_m_axi_rlast,
  input  logic [3:0]            dc_m_axi_rid,
  input  logic [1:0]            dc_m_axi_rresp,
  input  logic                  dc_m_axi_rvalid,
  output logic                  dc_m_axi_rready    
);

// instruction cache to CACHE_TO_NATIVE bridge
wire                  ic_to_nat_valid_i; 
wire                  ic_to_nat_valid_o;
wire [ADDR_BITS-1:0]  ic_to_nat_address_i;
wire [ADDR_BITS-1:0]  ic_to_nat_address_o;
wire [IC_DW-1:0]      ic_to_nat_data_i;

// data cache to CACHE_TO_NATIVE bridge
wire                  dc_to_nat_store_valid;
wire [ADDR_BITS-1:0]  dc_to_nat_store_addr;
wire [DC_DW-1:0]      dc_to_nat_store_data;
wire                  dc_to_nat_load_valid;
wire [ADDR_BITS-1:0]  dc_to_nat_load_addr;
wire                  dc_to_nat_update_valid;
wire [ADDR_BITS-1:0]  dc_to_nat_update_addr;
wire [DC_DW-1:0]      dc_to_nat_update_data;

// instruction CACHE_TO_NATIVE to AXI_MASTER
wire [ADDR_BITS-1:0]  ic_nat_to_axi_req_addr;
wire [1:0]            ic_nat_to_axi_req_op;
wire [IC_DW-1:0]      ic_nat_to_axi_req_data;
wire                  ic_nat_to_axi_req_valid;
wire                  ic_nat_to_axi_req_ready;
wire [IC_DW-1:0]      ic_nat_to_axi_upd_data;
wire                  ic_nat_to_axi_upd_valid;
wire                  ic_nat_to_axi_upd_ready;

// data CACHE_TO_NATIVE to AXI_MASTER
wire [ADDR_BITS-1:0]  dc_nat_to_axi_req_addr;
wire [1:0]            dc_nat_to_axi_req_op;
wire [DC_DW-1:0]      dc_nat_to_axi_req_data;
wire                  dc_nat_to_axi_req_valid;
wire                  dc_nat_to_axi_req_ready;
wire                  dc_nat_to_axi_upd_valid;
wire                  dc_nat_to_axi_upd_ready;
wire [DC_DW-1:0]      dc_nat_to_axi_upd_data;

//////////////////////////////////////////////////
//               INSTRUCTION CACHE              //
//////////////////////////////////////////////////
icache #(
  .ADDRESS_BITS       (ADDR_BITS),
  .ENTRIES            (IC_ENTRIES),
  .ASSOCIATIVITY      (ASSOCIATIVITY),
  .BLOCK_WIDTH        (IC_DW),
  .INSTR_BITS         (ISTR_DW)
) instuction_cache (
  .clk                (clk),
  .rst_n              (resetn),
  // processor side
  .address            (icache_current_pc),
  .hit                (icache_hit_icache),
  .miss               (icache_miss_icache),
  .half_access        (icache_half_fetch),
  .instruction_out    (icache_instruction_out),
  // bridge side
  .valid_o            (ic_to_nat_valid_o),
  .ready_in           (ic_to_nat_valid_i),
  .address_out        (ic_to_nat_address_o),
  .data_in            (ic_to_nat_data_i)
);

//////////////////////////////////////////////////
//                   DATA CACHE                 //
//////////////////////////////////////////////////
data_cache #(
  .DATA_WIDTH           (DATA_WIDTH),
  .ADDR_BITS            (ADDR_BITS),
  .R_WIDTH              (R_WIDTH),
  .MICROOP              (MICROOP_W),
  .ROB_TICKET           (ROB_TICKET_W),
  .ENTRIES              (DC_ENTRIES),
  .BLOCK_WIDTH          (DC_DW),
  .BUFFER_SIZES         (4),
  .ASSOCIATIVITY        (ASSOCIATIVITY)
) data_cache (
  .clk                  (clk),
  .rst_n                (resetn),
  .output_used          (dcache_output_used),
  //Load Input Port 
  .load_valid           (dcache_load_valid),
  .load_address         (dcache_load_address),
  .load_dest            (dcache_load_dest),
  .load_microop         (dcache_load_microop),
  .load_ticket          (dcache_load_ticket),
  //Store Input Port  
  .store_valid          (dcache_store_valid),
  .store_address        (dcache_store_address),
  .store_data           (dcache_store_data),
  .store_microop        (dcache_store_microop),
  //Request Write Port to L2  
  .write_l2_valid       (dc_to_nat_store_valid),
  .write_l2_addr        (dc_to_nat_store_addr),
  .write_l2_data        (dc_to_nat_store_data),
  //Request Read Port to L2 
  .request_l2_valid     (dc_to_nat_load_valid),
  .request_l2_addr      (dc_to_nat_load_addr),
  // Update Port from L2  
  .update_l2_valid      (dc_to_nat_update_valid),
  .update_l2_addr       (dc_to_nat_update_addr),
  .update_l2_data       (dc_to_nat_update_data),
  //Output Port 
  .cache_will_block     (dcache_will_block),
  .cache_blocked        (dcache_blocked),
  .served_output        (dcache_served_output)
);

generate
  if (USE_AXI) begin
    cache_to_native icache_to_nat (
      .clk(clk),
      .resetn(resetn),
      // cache side
      .cache_write_valid    ('d0),
      .cache_write_addr     ('d0),
      .cache_write_data     ('d0),
      .cache_read_valid     (ic_to_nat_valid_o),
      .cache_read_addr      (ic_to_nat_address_o),
      .cache_update_valid   (ic_to_nat_valid_i),
      .cache_update_addr    (ic_to_nat_address_i),
      .cache_update_data    (ic_to_nat_data_i),
      // to AXI master bridge
      .nat_request_valid    (ic_nat_to_axi_req_valid),
      .nat_request_ready    (ic_nat_to_axi_req_ready),
      .nat_request_op       (ic_nat_to_axi_req_op),
      .nat_request_addr     (ic_nat_to_axi_req_addr),
      .nat_request_data     (ic_nat_to_axi_req_data),
      .nat_update_valid     (ic_nat_to_axi_upd_valid),
      .nat_update_ready     (ic_nat_to_axi_upd_ready),
      .nat_update_data      (ic_nat_to_axi_upd_data)
    );

    AXI4_master # (
      .LS_DATA_WIDTH    (IC_DW),
      .ADDR_WIDTH       (ADDR_BITS),
      .DATA_WIDTH       (AXI_DW),
      .ID_WIDTH         (4),
      .RESP_WIDTH       (2),
      .ID_SEL           (0)
    ) icache_axi_master (
      .aclk             (clk),
      .aresetn          (resetn),
      // cache_to_nat bridge side
      .ls_address       (ic_nat_to_axi_req_addr),
      .ls_operation     (ic_nat_to_axi_req_op),
      .ls_data_in       (ic_nat_to_axi_req_data),
      .ls_valid_in      (ic_nat_to_axi_req_valid),
      .ls_ready_out     (ic_nat_to_axi_req_ready),
      .ls_data_out      (ic_nat_to_axi_upd_data),
      .ls_valid_out     (ic_nat_to_axi_upd_valid),
      .ls_ready_in      (ic_nat_to_axi_upd_ready),
      // AXI interface
      .AWVALID          (ic_m_axi_awvalid),
      .AWREADY          (ic_m_axi_awready),
      .AWADDR           (ic_m_axi_awaddr),
      .AWBURST          (ic_m_axi_awburst),
      .AWLEN            (ic_m_axi_awlen),
      .AWSIZE           (ic_m_axi_awsize),
      .AWID             (ic_m_axi_awid),
      .WVALID           (ic_m_axi_wvalid),
      .WREADY           (ic_m_axi_wready),
      .WDATA            (ic_m_axi_wdata),
      .WLAST            (ic_m_axi_wlast),
      .WSTRB            (ic_m_axi_wstrb),
      .BID              (ic_m_axi_bid),
      .BRESP            (ic_m_axi_bresp),
      .BVALID           (ic_m_axi_bvalid),
      .BREADY           (ic_m_axi_bready),
      .ARREADY          (ic_m_axi_arready),
      .ARVALID          (ic_m_axi_arvalid),
      .ARADDR           (ic_m_axi_araddr),
      .ARBURST          (ic_m_axi_arburst),
      .ARLEN            (ic_m_axi_arlen),
      .ARSIZE           (ic_m_axi_arsize),
      .ARID             (ic_m_axi_arid),
      .RDATA            (ic_m_axi_rdata),
      .RLAST            (ic_m_axi_rlast),
      .RID              (ic_m_axi_rid),
      .RRESP            (ic_m_axi_rresp),
      .RVALID           (ic_m_axi_rvalid),
      .RREADY           (ic_m_axi_rready)
    );


    cache_to_native dcache_to_nat (
      .clk                  (clk),
      .resetn               (resetn),
      // cache side
      .cache_write_valid    (dc_to_nat_store_valid),
      .cache_write_addr     (dc_to_nat_store_addr),
      .cache_write_data     (dc_to_nat_store_data),
      .cache_read_valid     (dc_to_nat_load_valid),
      .cache_read_addr      (dc_to_nat_load_addr),
      .cache_update_valid   (dc_to_nat_update_valid),
      .cache_update_addr    (dc_to_nat_update_addr),
      .cache_update_data    (dc_to_nat_update_data),
      // to AXI master bridge
      .nat_request_valid    (dc_nat_to_axi_req_valid),
      .nat_request_ready    (dc_nat_to_axi_req_ready),
      .nat_request_op       (dc_nat_to_axi_req_op),
      .nat_request_addr     (dc_nat_to_axi_req_addr),
      .nat_request_data     (dc_nat_to_axi_req_data),
      .nat_update_valid     (dc_nat_to_axi_upd_valid),
      .nat_update_ready     (dc_nat_to_axi_upd_ready),
      .nat_update_data      (dc_nat_to_axi_upd_data)
    );

    AXI4_master # (
      .LS_DATA_WIDTH        (256),
      .ADDR_WIDTH           (32),
      .DATA_WIDTH           (32),
      .ID_WIDTH             (4),
      .RESP_WIDTH           (2),
      .ID_SEL               (1)
    ) dcache_axi_master (
      .aclk                 (clk),
      .aresetn              (resetn),
      // cache_to_nat bridge side
      .ls_address           (dc_nat_to_axi_req_addr),
      .ls_operation         (dc_nat_to_axi_req_op),
      .ls_data_in           (dc_nat_to_axi_req_data),
      .ls_valid_in          (dc_nat_to_axi_req_valid),
      .ls_ready_out         (dc_nat_to_axi_req_ready),
      .ls_data_out          (dc_nat_to_axi_upd_data),
      .ls_valid_out         (dc_nat_to_axi_upd_valid),
      .ls_ready_in          (dc_nat_to_axi_upd_ready),
      // AXI interface
      .AWVALID              (dc_m_axi_awvalid),
      .AWREADY              (dc_m_axi_awready),
      .AWADDR               (dc_m_axi_awaddr),
      .AWBURST              (dc_m_axi_awburst),
      .AWLEN                (dc_m_axi_awlen),
      .AWSIZE               (dc_m_axi_awsize),
      .AWID                 (dc_m_axi_awid),
      .WVALID               (dc_m_axi_wvalid),
      .WREADY               (dc_m_axi_wready),
      .WDATA                (dc_m_axi_wdata),
      .WLAST                (dc_m_axi_wlast),
      .WSTRB                (dc_m_axi_wstrb),
      .BID                  (dc_m_axi_bid),
      .BRESP                (dc_m_axi_bresp),
      .BVALID               (dc_m_axi_bvalid),
      .BREADY               (dc_m_axi_bready),
      .ARREADY              (dc_m_axi_arready),
      .ARVALID              (dc_m_axi_arvalid),
      .ARADDR               (dc_m_axi_araddr),
      .ARBURST              (dc_m_axi_arburst),
      .ARLEN                (dc_m_axi_arlen),
      .ARSIZE               (dc_m_axi_arsize),
      .ARID                 (dc_m_axi_arid),
      .RDATA                (dc_m_axi_rdata),
      .RLAST                (dc_m_axi_rlast),
      .RID                  (dc_m_axi_rid),
      .RRESP                (dc_m_axi_rresp),
      .RVALID               (dc_m_axi_rvalid),
      .RREADY               (dc_m_axi_rready)
    );

    assign valid_out = 1'd0;
    assign address_out = '{default: 'd0};
    assign write_l2_valid = 1'd0;
    assign write_l2_addr = '{default: 'd0};
    assign write_l2_data = '{default: 'd0};
    assign request_l2_valid = 1'd0;
    assign request_l2_addr = '{default: 'd0};

  end else begin

    assign valid_out = ic_to_nat_valid_o;
    assign address_out = ic_to_nat_address_o;
    assign ic_to_nat_valid_i = ready_in; 
    assign ic_to_nat_data_i = data_in;

    assign write_l2_valid = dc_to_nat_store_valid;
    assign write_l2_addr = dc_to_nat_store_addr;
    assign write_l2_data = dc_to_nat_store_data;
    assign request_l2_valid = dc_to_nat_load_valid;
    assign request_l2_addr = dc_to_nat_load_addr;
    assign dc_to_nat_update_valid = update_l2_valid;
    assign dc_to_nat_update_addr = update_l2_addr;
    assign dc_to_nat_update_data = update_l2_data;

    assign ic_axi_awvalid = 1'd0;
    assign ic_axi_awaddr = '{default: 'd0};
    assign ic_axi_awburst = 2'd0;
    assign ic_axi_awlen = 8'd0;
    assign ic_axi_awsize = 3'd0;
    assign ic_axi_awid = 4'd0;
    assign ic_axi_wvalid = 1'd0;
    assign ic_axi_wdata = '{default: 'd0};
    assign ic_axi_wlast = 1'd0;
    assign ic_axi_wstrb = 4'd0;
    assign ic_axi_bready = 1'd0;
    assign ic_axi_arvalid = 1'd0;
    assign ic_axi_araddr = '{default: 'd0};
    assign ic_axi_arburst = 2'd0;
    assign ic_axi_arlen = 8'd0;
    assign ic_axi_arsize = 3'd0;
    assign ic_axi_arid = 4'd0;
    assign ic_axi_rready = 1'd0;
    assign dc_axi_awvalid = 1'd0;
    assign dc_axi_awaddr = '{default: 'd0};
    assign dc_axi_awburst = 2'd0;
    assign dc_axi_awlen = 8'd0;
    assign dc_axi_awsize = 3'd0;
    assign dc_axi_awid = 4'd0;
    assign dc_axi_wvalid = 1'd0;
    assign dc_axi_wdata = '{default: 'd0};
    assign dc_axi_wlast = 1'd0;
    assign dc_axi_wstrb = 4'd0;
    assign dc_axi_bready = 1'd0;
    assign dc_axi_arvalid = 1'd0;
    assign dc_axi_araddr = '{default: 'd0};
    assign dc_axi_arburst = 2'd0;
    assign dc_axi_arlen = 7'd0;
    assign dc_axi_arsize = 3'd0;
    assign dc_axi_arid = 4'd0;
    assign dc_axi_rready = 1'd0;
  end
endgenerate

endmodule