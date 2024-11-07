module main_memory_top #(
  parameter USE_AXI         = 0,
  parameter L2_BLOCK_DW     = 128 ,
  parameter L2_ENTRIES      = 2048,
  parameter ADDRESS_BITS    = 32  ,
  parameter ICACHE_BLOCK_DW = 256 ,
  parameter DCACHE_BLOCK_DW = 256 ,
  parameter REALISTIC       = 1   ,
  parameter DELAY_CYCLES    = 50  ,
  parameter FILE_NAME       = "memory.mem",
  parameter ID_W            = 4,
  parameter ADDR_W          = 32,
  parameter AXI_DW          = 32,
  parameter RESP_W          = 2,
  // local parameters
  localparam NBYTES         = AXI_DW/8
)(
  input   logic                 clk_i,
  input   logic                 rst_n_i,

  //Read Request Input from ICache
  input   logic                       icache_valid_i,
  input   logic [         ADDR_W-1:0] icache_address_i,
  //Read Request Input from DCache
  input   logic                       dcache_valid_i,
  input   logic [         ADDR_W-1:0] dcache_address_i,
  //Write Request Input from DCache
  input   logic                       write_l2_valid,
  input   logic [         ADDR_W-1:0] write_l2_addr,
  input   logic [DCACHE_BLOCK_DW-1:0] write_l2_data,
  //Output to ICache
  output  logic                       icache_valid_o,
  output  logic [ICACHE_BLOCK_DW-1:0] icache_data_o,
  //Output to DCache
  output  logic                       dcache_valid_o,
  output  logic [         ADDR_W-1:0] dcache_address_o,
  output  logic [DCACHE_BLOCK_DW-1:0] dcache_data_o,

  // AXI interfaces
  input   logic                 ic_s_axi_awvalid,
  output  logic                 ic_s_axi_awready,
  input   logic [ADDR_W-1:0]    ic_s_axi_awaddr,
  input   burst_type            ic_s_axi_awburst,
  input   logic [7:0]           ic_s_axi_awlen,
  input   logic [2:0]           ic_s_axi_awsize,
  input   logic [ID_W-1:0]      ic_s_axi_awid,
  input   logic                 ic_s_axi_wvalid,
  output  logic                 ic_s_axi_wready,
  input   logic [AXI_DW-1:0]    ic_s_axi_wdata,
  input   logic                 ic_s_axi_wlast,
  input   logic [NBYTES-1:0]    ic_s_axi_wstrb,
  output  logic [ID_W-1:0]      ic_s_axi_bid,
  output  logic [RESP_W-1:0]    ic_s_axi_bresp,
  output  logic                 ic_s_axi_bvalid,
  input   logic                 ic_s_axi_bready,
  output  logic                 ic_s_axi_arready,
  input   logic                 ic_s_axi_arvalid,
  input   logic [ADDR_W-1:0]    ic_s_axi_araddr,
  input   burst_type            ic_s_axi_arburst,
  input   logic [7:0]           ic_s_axi_arlen,
  input   logic [2:0]           ic_s_axi_arsize,
  input   logic [ID_W-1:0]      ic_s_axi_arid,
  output  logic [AXI_DW-1:0]    ic_s_axi_rdata,
  output  logic                 ic_s_axi_rlast,
  output  logic [ID_W-1:0]      ic_s_axi_rid,
  output  logic [RESP_W-1:0]    ic_s_axi_rresp,
  output  logic                 ic_s_axi_rvalid,
  input   logic                 ic_s_axi_rready,

  input   logic                 dc_s_axi_awvalid,
  output  logic                 dc_s_axi_awready,
  input   logic [ADDR_W-1:0]    dc_s_axi_awaddr,
  input   burst_type            dc_s_axi_awburst,
  input   logic [7:0]           dc_s_axi_awlen,
  input   logic [2:0]           dc_s_axi_awsize,
  input   logic [ID_W-1:0]      dc_s_axi_awid,
  input   logic                 dc_s_axi_wvalid,
  output  logic                 dc_s_axi_wready,
  input   logic [AXI_DW-1:0]    dc_s_axi_wdata,
  input   logic                 dc_s_axi_wlast,
  input   logic [NBYTES-1:0]    dc_s_axi_wstrb,
  output  logic [ID_W-1:0]      dc_s_axi_bid,
  output  logic [RESP_W-1:0]    dc_s_axi_bresp,
  output  logic                 dc_s_axi_bvalid,
  input   logic                 dc_s_axi_bready,
  output  logic                 dc_s_axi_arready,
  input   logic                 dc_s_axi_arvalid,
  input   logic [ADDR_W-1:0]    dc_s_axi_araddr,
  input   burst_type            dc_s_axi_arburst,
  input   logic [7:0]           dc_s_axi_arlen,
  input   logic [2:0]           dc_s_axi_arsize,
  input   logic [ID_W-1:0]      dc_s_axi_arid,
  output  logic [AXI_DW-1:0]    dc_s_axi_rdata,
  output  logic                 dc_s_axi_rlast,
  output  logic [ID_W-1:0]      dc_s_axi_rid,
  output  logic [RESP_W-1:0]    dc_s_axi_rresp,
  output  logic                 dc_s_axi_rvalid,
  input   logic                 dc_s_axi_rready
);

logic                       icache_valid_i_s;
logic [ADDR_W-1:0]          icache_address_i_s;

logic                       icache_valid_o_s;
logic [ICACHE_BLOCK_DW-1:0] icache_data_o_s;

logic                       dcache_valid_i_s;
logic [ADDR_W-1:0]          dcache_address_i_s;

logic                       dcache_valid_o_s;
logic [ADDR_W-1:0]          dcache_address_o_s;
logic [DCACHE_BLOCK_DW-1:0] dcache_data_o_s;

logic                       write_l2_valid_s;
logic [ADDR_W-1:0]          write_l2_addr_s;
logic [DCACHE_BLOCK_DW-1:0] write_l2_data_s;

main_memory #(
  .L2_BLOCK_DW    (L2_BLOCK_DW),
  .L2_ENTRIES     (L2_ENTRIES),
  .ADDRESS_BITS   (ADDRESS_BITS),
  .ICACHE_BLOCK_DW(ICACHE_BLOCK_DW),
  .DCACHE_BLOCK_DW(DCACHE_BLOCK_DW),
  .REALISTIC      (REALISTIC),
  .DELAY_CYCLES   (DELAY_CYCLES),
  .FILE_NAME      ("memory.mem")
) main_memory (
  .clk              (clk_i             ),
  .rst_n            (rst_n_i           ),
  //Read Request Input from ICache
  .icache_valid_i   (icache_valid_i_s  ),
  .icache_address_i (icache_address_i_s),
  //Output to ICache
  .icache_valid_o   (icache_valid_o_s  ),
  .icache_data_o    (icache_data_o_s   ),
  //Read Request Input from DCache
  .dcache_valid_i   (dcache_valid_i_s  ),
  .dcache_address_i (dcache_address_i_s),
  //Output to DCache
  .dcache_valid_o   (dcache_valid_o_s  ),
  .dcache_address_o (dcache_address_o_s),
  .dcache_data_o    (dcache_data_o_s   ),
  //Write Request Input from DCache
  .dcache_valid_wr  (write_l2_valid_s  ),
  .dcache_address_wr(write_l2_addr_s   ),
  .dcache_data_wr   (write_l2_data_s   )
);

generate
  if (USE_AXI) begin

    AXI4_slave # (
      .ID_W       (ID_W),
      .ADDR_W     (ADDR_W),
      .AXI_DW     (AXI_DW),
      .RESP_W     (RESP_W),
      .NATIVE_DW  (ICACHE_BLOCK_DW)
    ) icache_interface (
      .aclk_i           (clk_i),
      .aresetn_i        (rst_n_i),
      .nat_write_valid_o(),
      .nat_write_addr_o (),
      .nat_write_data_o (),
      .nat_read_valid_o (icache_valid_i_s),
      .nat_read_addr_o  (icache_address_i_s),
      .nat_read_valid_i (icache_valid_o_s),
      .nat_read_addr_i  ({ADDR_W{1'b0}}),
      .nat_read_data_i  (icache_data_o_s),

      .s_axi_awvalid_i  (ic_s_axi_awvalid),
      .s_axi_awready_o  (ic_s_axi_awready),
      .s_axi_awaddr_i   (ic_s_axi_awaddr),
      .s_axi_awburst_i  (ic_s_axi_awburst),
      .s_axi_awlen_i    (ic_s_axi_awlen),
      .s_axi_awsize_i   (ic_s_axi_awsize),
      .s_axi_awid_i     (ic_s_axi_awid),
      .s_axi_wvalid_i   (ic_s_axi_wvalid),
      .s_axi_wready_o   (ic_s_axi_wready),
      .s_axi_wdata_i    (ic_s_axi_wdata),
      .s_axi_wlast_i    (ic_s_axi_wlast),
      .s_axi_wstrb_i    (ic_s_axi_wstrb),
      .s_axi_bid_o      (ic_s_axi_bid),
      .s_axi_bresp_o    (ic_s_axi_bresp),
      .s_axi_bvalid_o   (ic_s_axi_bvalid),
      .s_axi_bready_i   (ic_s_axi_bready),
      .s_axi_arready_o  (ic_s_axi_arready),
      .s_axi_arvalid_i  (ic_s_axi_arvalid),
      .s_axi_araddr_i   (ic_s_axi_araddr),
      .s_axi_arburst_i  (ic_s_axi_arburst),
      .s_axi_arlen_i    (ic_s_axi_arlen),
      .s_axi_arsize_i   (ic_s_axi_arsize),
      .s_axi_arid_i     (ic_s_axi_arid),
      .s_axi_rdata_o    (ic_s_axi_rdata),
      .s_axi_rlast_o    (ic_s_axi_rlast),
      .s_axi_rid_o      (ic_s_axi_rid),
      .s_axi_rresp_o    (ic_s_axi_rresp),
      .s_axi_rvalid_o   (ic_s_axi_rvalid),
      .s_axi_rready_i   (ic_s_axi_rready)
    );
    
    AXI4_slave # (
      .ID_W       (ID_W),
      .ADDR_W     (ADDR_W),
      .AXI_DW     (AXI_DW),
      .RESP_W     (RESP_W),
      .NATIVE_DW  (DCACHE_BLOCK_DW)
    ) dcache_interface (
      .aclk_i           (clk_i),
      .aresetn_i        (rst_n_i),
      .nat_write_valid_o(write_l2_valid_s),
      .nat_write_addr_o (write_l2_addr_s),
      .nat_write_data_o (write_l2_data_s),
      .nat_read_valid_o (dcache_valid_i_s),
      .nat_read_addr_o  (dcache_address_i_s),
      .nat_read_valid_i (dcache_valid_o_s),
      .nat_read_addr_i  (dcache_address_o_s),
      .nat_read_data_i  (dcache_data_o_s),
      
      .s_axi_awvalid_i  (dc_s_axi_awvalid),
      .s_axi_awready_o  (dc_s_axi_awready),
      .s_axi_awaddr_i   (dc_s_axi_awaddr),
      .s_axi_awburst_i  (dc_s_axi_awburst),
      .s_axi_awlen_i    (dc_s_axi_awlen),
      .s_axi_awsize_i   (dc_s_axi_awsize),
      .s_axi_awid_i     (dc_s_axi_awid),
      .s_axi_wvalid_i   (dc_s_axi_wvalid),
      .s_axi_wready_o   (dc_s_axi_wready),
      .s_axi_wdata_i    (dc_s_axi_wdata),
      .s_axi_wlast_i    (dc_s_axi_wlast),
      .s_axi_wstrb_i    (dc_s_axi_wstrb),
      .s_axi_bid_o      (dc_s_axi_bid),
      .s_axi_bresp_o    (dc_s_axi_bresp),
      .s_axi_bvalid_o   (dc_s_axi_bvalid),
      .s_axi_bready_i   (dc_s_axi_bready),
      .s_axi_arready_o  (dc_s_axi_arready),
      .s_axi_arvalid_i  (dc_s_axi_arvalid),
      .s_axi_araddr_i   (dc_s_axi_araddr),
      .s_axi_arburst_i  (dc_s_axi_arburst),
      .s_axi_arlen_i    (dc_s_axi_arlen),
      .s_axi_arsize_i   (dc_s_axi_arsize),
      .s_axi_arid_i     (dc_s_axi_arid),
      .s_axi_rdata_o    (dc_s_axi_rdata),
      .s_axi_rlast_o    (dc_s_axi_rlast),
      .s_axi_rid_o      (dc_s_axi_rid),
      .s_axi_rresp_o    (dc_s_axi_rresp),
      .s_axi_rvalid_o   (dc_s_axi_rvalid),
      .s_axi_rready_i   (dc_s_axi_rready)
    );

    assign icache_valid_o = 1'b0;
    assign icache_data_o = {ICACHE_BLOCK_DW{1'b0}};

    assign dcache_valid_o = 1'b0;
    assign dcache_address_o = {ADDR_W{1'b0}};
    assign dcache_data_o = {DCACHE_BLOCK_DW{1'b0}};

  end else begin

    assign icache_valid_i_s = icache_valid_i;
    assign icache_address_i_s = icache_address_i;
    assign dcache_valid_i_s = dcache_valid_i;
    assign dcache_address_i_s = dcache_address_i;
    assign write_l2_valid_s = write_l2_valid;
    assign write_l2_addr_s = write_l2_addr;
    assign write_l2_data_s = write_l2_data;

    assign icache_valid_o = icache_valid_o_s;
    assign icache_data_o = icache_data_o_s;
    assign dcache_valid_o = dcache_valid_o_s;
    assign dcache_address_o = dcache_address_o_s;
    assign dcache_data_o = dcache_data_o_s;


    assign ic_s_axi_awready = 1'b0;
    assign ic_s_axi_wready = 1'b0;
    assign ic_s_axi_bid = {ID_W{1'b0}};
    assign ic_s_axi_bresp = {RESP_W{1'b0}};
    assign ic_s_axi_bvalid = 1'b0;
    assign ic_s_axi_arready = 1'b0;
    assign ic_s_axi_rdata = {AXI_DW{1'b0}};
    assign ic_s_axi_rlast = 1'b0;
    assign ic_s_axi_rid = {ID_W{1'b0}};
    assign ic_s_axi_rresp = {RESP_W{1'b0}};
    assign ic_s_axi_rvalid = 1'b0;

    assign dc_s_axi_awready = 1'b0;
    assign dc_s_axi_wready = 1'b0;
    assign dc_s_axi_bid = {ID_W{1'b0}};
    assign dc_s_axi_bresp = {RESP_W{1'b0}};
    assign dc_s_axi_bvalid = 1'b0;
    assign dc_s_axi_arready = 1'b0;
    assign dc_s_axi_rdata = {AXI_DW{1'b0}};
    assign dc_s_axi_rlast = 1'b0;
    assign dc_s_axi_rid = {ID_W{1'b0}};
    assign dc_s_axi_rresp = {RESP_W{1'b0}};
    assign dc_s_axi_rvalid = 1'b0;

  end
endgenerate



endmodule