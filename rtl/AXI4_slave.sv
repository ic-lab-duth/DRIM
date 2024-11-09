// Only incremented bursts are implemented

module AXI4_slave #(
  parameter ID_W      = 4,    //! Number of Transaction ID bits
  parameter ADDR_W    = 32,   //! Number of Address bits  
  parameter AXI_DW    = 32,   //! Number of AXI Data bits
  parameter RESP_W    = 2,    //! Number of Response bits
  parameter NATIVE_DW = 256,  //! Number of Left-side Data bits
  // local parameters
  localparam NBYTES   = AXI_DW/8,                           //! Number of Bytes per word.
  localparam NTRANSF  = NATIVE_DW/AXI_DW,                   //! Required number of transfers per transaction.
  localparam LEN_W    = (NTRANSF==1) ? 1 : $clog2(NTRANSF)  //! Required number of bits for the write and read_index to count the number of transfers.
)(
  input logic aclk_i,             //! AXI clock
  input logic aresetn_i,          //! Active LOW reset signal

  // Native signals
  output logic                  nat_write_valid_o,
  output logic [ADDR_W-1:0]     nat_write_addr_o,
  output logic [NATIVE_DW-1:0]  nat_write_data_o,
  
  output logic                  nat_read_valid_o,
  output logic [ADDR_W-1:0]     nat_read_addr_o,
  input  logic                  nat_read_valid_i,
  input  logic [ADDR_W-1:0]     nat_read_addr_i,
  input  logic [NATIVE_DW-1:0]  nat_read_data_i,
  //! @end

  //! @virtualbus AXI_Master @dir out AXI Write and Read channels
  // write request channel
  //! AWVALID is HIGH when the master holds valid request signals for a slave.
  input  logic                    s_axi_awvalid_i,  
  output logic                    s_axi_awready_o,  //! AWREADY is HIGH when the slave can accept a request.
  input  logic [ADDR_W-1:0]       s_axi_awaddr_i,   //! Holds the address of the first transfer in a Write transaction.
  input  burst_type               s_axi_awburst_i,  //! Describes how the address increments between transfers in a transaction. In this case always Incrimental.
  input  logic [7:0]              s_axi_awlen_i,    //! The total number of transfers in a transaction, encoded as: Length=AxLEN+1. In this case always 7.
  input  logic [2:0]              s_axi_awsize_i,   //! Indicates the maximum number of bytes in each data transfer within a transaction. In this case always 4.
  input  logic [ID_W-1:0]         s_axi_awid_i,     //! Transaction ID. In this case every master has a fixed ID selected by the ID_SEL parameter.

  // write data channel
  input  logic                    s_axi_wvalid_i,   //! WVALID is HIGH when the master holds valid data signals for a slave.
  output logic                    s_axi_wready_o,   //! WREADY is HIGH when the slave can accept a request.
  input  logic [AXI_DW-1:0]       s_axi_wdata_i,    //! Write data.
  input  logic                    s_axi_wlast_i,    //! Indicates the last write data transfer of a transaction.
  input  logic [NBYTES-1:0]       s_axi_wstrb_i,    //! Indicates which byte lanes of WDATA contain valid data in a write transaction.

  // write response channel
  output logic [ID_W-1:0]         s_axi_bid_o,      //! Write Response ID.
  output logic [RESP_W-1:0]       s_axi_bresp_o,    //! Returns success or failure of the transaction.
  output logic                    s_axi_bvalid_o,   //! BVALID is HIGH when a slave holds valid Response signals for the master.
  input  logic                    s_axi_bready_i,   //! BREADY is HIGH when the master can accept a Response.

  // read request channel
  output logic                    s_axi_arready_o,  //! ARREADY is HIGH when a slave can accept a request.
  input  logic                    s_axi_arvalid_i,  //! ARVALID is HIGH when the master holds valid Request signals for a slave.
  input  logic [ADDR_W-1:0]       s_axi_araddr_i,   //! Holds the address of the first transfer in a Read transaction.
  input  burst_type               s_axi_arburst_i,  //! Describes how the address increments between transfers in a transaction. In this case always Incrimental.
  input  logic [7:0]              s_axi_arlen_i,    //! The total number of transfers in a transaction, encoded as: Length=AxLEN+1. In this case always 7.
  input  logic [2:0]              s_axi_arsize_i,   //! Indicates the maximum number of bytes in each data transfer within a transaction. In this case always 4.
  input  logic [ID_W-1:0]         s_axi_arid_i,     //! Transaction ID. In this case every master has a fixed ID selected by the ID_SEL parameter.

  // read data channel
  output logic [AXI_DW-1:0]       s_axi_rdata_o,    //! Read data.
  output logic                    s_axi_rlast_o,    //! Indicates the last read data transfer of a transaction.
  output logic [ID_W-1:0]         s_axi_rid_o,      //! Read Response ID.
  output logic [RESP_W-1:0]       s_axi_rresp_o,    //! Returns success or failure of the transaction.
  output logic                    s_axi_rvalid_o,   //! RVALID is HIGH when a slave holds valid Response signals for the master.
  input  logic                    s_axi_rready_i    //! RREADY is HIGH when the master can accept a Response.
  //! @end
);

typedef enum logic [1:0] { W_IDLE, W_AXI_WDATA, W_AXI_BRESP, W_NAT_UPDATE } write_fsm;
write_fsm write_st_s;
typedef enum logic [1:0] { R_IDLE, R_NAT_ACCESS, R_NAT_UPDATE, R_AXI_RDATA } read_fsm;
read_fsm read_st_s;

localparam OFFSET_W = (NTRANSF==1) ? 1 : $clog2(NTRANSF);
logic [OFFSET_W-1:0] write_offset_s;
logic [OFFSET_W-1:0] read_offset_s;

logic [NATIVE_DW-1:0] write_word_buffer_s;
logic [NATIVE_DW-1:0] read_word_buffer_s;

always_ff @(posedge aclk_i) begin
  if (!aresetn_i) begin
    write_st_s <= W_IDLE;
  end else begin
    case (write_st_s)
      W_IDLE:       begin
                      if (s_axi_awvalid_i && s_axi_awready_o) begin
                        write_st_s <= W_AXI_WDATA;
                      end
                    end

      W_AXI_WDATA:  begin
                      if (s_axi_wvalid_i && s_axi_wready_o && s_axi_wlast_i) begin
                        write_st_s <= W_AXI_BRESP;
                      end
                    end

      W_AXI_BRESP:  begin
                      if (s_axi_bvalid_o && s_axi_bready_i) begin
                        write_st_s <= W_NAT_UPDATE;
                      end
                    end

      W_NAT_UPDATE: begin
                      write_st_s <= W_IDLE; 
                    end

      default:      begin
                      write_st_s <= W_IDLE;
                    end

    endcase
  end
end

always_ff @(posedge aclk_i) begin
  if (!aresetn_i) begin
    read_st_s <= R_IDLE;
  end else begin
    case (read_st_s)
      R_IDLE:       begin
                      if (s_axi_arvalid_i && s_axi_arready_o) begin
                        read_st_s <= R_NAT_ACCESS;
                      end
                    end

      R_NAT_ACCESS: begin
                      if (nat_read_valid_o) begin
                        read_st_s <= R_NAT_UPDATE;
                      end
                    end

      R_NAT_UPDATE: begin
                      if (nat_read_valid_i) begin
                        read_st_s <= R_AXI_RDATA; 
                      end
                    end

      R_AXI_RDATA:  begin
                      if (s_axi_rvalid_o && s_axi_rready_i && s_axi_rlast_o) begin
                        read_st_s <= R_IDLE; 
                      end
                    end

      default:      begin
                      read_st_s <= R_IDLE;
                    end

    endcase
  end
end

always_ff @(posedge aclk_i) begin
  if (!aresetn_i) begin 
    write_offset_s <= 0;
  end else begin
    if (s_axi_wvalid_i && s_axi_wready_o) begin
      if (write_offset_s==NTRANSF-1) begin
        write_offset_s <= 0;
      end else begin
        write_offset_s <= write_offset_s + 1;
      end
    end
  end
end

always_ff @(posedge aclk_i) begin
  if (!aresetn_i) begin 
    read_offset_s <= 0;
  end else begin
    if (s_axi_rvalid_o && s_axi_rready_i) begin
      if (read_offset_s==NTRANSF-1) begin
        read_offset_s <= 0;
      end else begin
        read_offset_s <= read_offset_s + 1;
      end
    end
  end
end

always_ff @(posedge aclk_i) begin : WRITE_WORD_BUFFER
  if (!aresetn_i) begin
    write_word_buffer_s <= '{default: '0};
  end else begin
    if (s_axi_wvalid_i && s_axi_wready_o) begin
      write_word_buffer_s[write_offset_s*AXI_DW+:AXI_DW] <= s_axi_wdata_i;
    end
  end
end

always_ff @(posedge aclk_i) begin : READ_WORD_BUFFER
  if (!aresetn_i) begin
    read_word_buffer_s <= '{default: '0};
  end else begin
    if (nat_read_valid_i) begin
      read_word_buffer_s <= nat_read_data_i;
    end
  end
end

logic [ADDR_W-1:0]  write_addr_r;
logic [7:0]         write_len_r;
logic [ID_W-1:0]    write_id_r;
always_ff @(posedge aclk_i) begin
  if (!aresetn_i || write_st_s==W_NAT_UPDATE) begin
    write_addr_r <= '{default: '0};
    write_len_r <= '{default: '0};
    write_id_r <= '{default: '0};
  end else begin
    if (s_axi_awvalid_i && s_axi_awready_o) begin
      write_addr_r <= s_axi_awaddr_i;
      write_len_r <= s_axi_awlen_i;
      write_id_r <= s_axi_awid_i;
    end
  end
end

logic [ADDR_W-1:0]  read_addr_r;
logic [7:0]         read_len_r;
logic [ID_W-1:0]    read_id_r;
always_ff @(posedge aclk_i) begin
  if (!aresetn_i || s_axi_rlast_o) begin
    read_addr_r <= '{default: '0};
    read_len_r <= '{default: '0};
    read_id_r <= '{default: '0};
  end else begin
    if (s_axi_arvalid_i && s_axi_arready_o) begin
      read_addr_r <= s_axi_araddr_i;
      read_len_r <= s_axi_arlen_i;
      read_id_r <= s_axi_arid_i;
    end
  end
end

assign s_axi_awready_o = (write_st_s==W_IDLE && s_axi_awvalid_i && (s_axi_awaddr_i!=read_addr_r || read_addr_r==0));
assign s_axi_wready_o = (write_st_s==W_AXI_WDATA);
assign s_axi_bvalid_o = (write_st_s==W_AXI_BRESP);
assign s_axi_bid_o = write_id_r;
assign s_axi_bresp_o = 2'b00;

assign nat_write_valid_o = (write_st_s==W_NAT_UPDATE);
assign nat_write_addr_o = write_addr_r;
assign nat_write_data_o = write_word_buffer_s; 


assign s_axi_arready_o = (read_st_s==R_IDLE && s_axi_arvalid_i && (s_axi_araddr_i!=write_addr_r || write_addr_r==0));
assign s_axi_rvalid_o = (read_st_s==R_AXI_RDATA);
assign s_axi_rdata_o = read_word_buffer_s[read_offset_s*AXI_DW+:AXI_DW];
assign s_axi_rlast_o = (read_offset_s==NTRANSF-1);
assign s_axi_rresp_o = 2'b00;
assign s_axi_rid_o = read_id_r;
assign nat_read_valid_o = (read_st_s==R_NAT_ACCESS);
assign nat_read_addr_o = read_addr_r;

endmodule