//! During a write transaction, the master holds the required signals with the information for the transaction.
//! When the AWVALID-AWREADY handshake happens, it starts sending the data until it sents the last transfer of the transaction.
//! After that, it waits for the BRESP signal that informs the master whether or not the transaction was successful.
//! This master has to wait until it gets a response for the latest write transaction to initialize another request.

typedef enum logic [1:0] {FIXED, INCR, WRAP, NOOP} burst_type;

//! @title Simple valid.ready to AXI4 Master
//! @author Giorgos Pelekidis
module AXI4_master #(
  parameter ID_SEL        = 0,    //! Master's ID
  parameter ID_WIDTH      = 4,    //! Number of Transaction ID bits
  parameter ADDR_WIDTH    = 32,   //! Number of Address bits  
  parameter DATA_WIDTH    = 32,   //! Number of AXI Data bits
  parameter RESP_WIDTH    = 2,    //! Number of Response bits
  parameter LS_DATA_WIDTH = 256,  //! Number of Left-side Data bits
  // local parameters
  localparam NBYTES       = DATA_WIDTH/8,                       //! Number of Bytes per word.
  localparam NTRANSF      = LS_DATA_WIDTH/DATA_WIDTH,           //! Required number of transfers per transaction.
  localparam LEN_W        = (NTRANSF==1) ? 1 : $clog2(NTRANSF) //! Required number of bits for the write and read_index to count the number of transfers.
)(
  input logic aclk,               //! AXI clock
  input logic aresetn,            //! Active LOW reset signal

  // Left side signals
  //! @virtualbus Valid-Ready_Interface @dir in Simple Valid-Ready Request and Return channels
  input  logic [ADDR_WIDTH-1:0]    ls_address,    //! Memory Address for the transaction
  input  logic [1:0]               ls_operation,  //! Write, Read or No operation

  input  logic [LS_DATA_WIDTH-1:0] ls_data_in,    //! Write Data
  input  logic                     ls_valid_in,   //! Valid Request signal
  output logic                     ls_ready_out,  //! Ready Request signal

  output logic [LS_DATA_WIDTH-1:0] ls_data_out,   //! Read Data
  output logic                     ls_valid_out,  //! Valid Return signal
  input  logic                     ls_ready_in,   //! Ready Return signal
  //! @end

  //! @virtualbus AXI_Master @dir out AXI Write and Read channels
  // write request channel
  //! AWVALID is HIGH when the master holds valid request signals for a slave.
  output logic                    AWVALID,  
  input  logic                    AWREADY,  //! AWREADY is HIGH when the slave can accept a request.
  output logic [ADDR_WIDTH-1:0]   AWADDR,   //! Holds the address of the first transfer in a Write transaction.
  output burst_type               AWBURST,  //! Describes how the address increments between transfers in a transaction. In this case always Incrimental.
  output logic [7:0]              AWLEN,    //! The total number of transfers in a transaction, encoded as: Length=AxLEN+1. In this case always 7.
  output logic [2:0]              AWSIZE,   //! Indicates the maximum number of bytes in each data transfer within a transaction. In this case always 4.
  output logic [ID_WIDTH-1:0]     AWID,     //! Transaction ID. In this case every master has a fixed ID selected by the ID_SEL parameter.

  // write data channel

  output logic                    WVALID,   //! WVALID is HIGH when the master holds valid data signals for a slave.
  input  logic                    WREADY,   //! WREADY is HIGH when the slave can accept a request.
  output logic [DATA_WIDTH-1:0]   WDATA,    //! Write data.
  output logic                    WLAST,    //! Indicates the last write data transfer of a transaction.
  output logic [NBYTES-1:0]       WSTRB,    //! Indicates which byte lanes of WDATA contain valid data in a write transaction.

  // write response channel
  input  logic [ID_WIDTH-1:0]     BID,      //! Write Response ID.
  input  logic [RESP_WIDTH-1:0]   BRESP,    //! Returns success or failure of the transaction.
  input  logic                    BVALID,   //! BVALID is HIGH when a slave holds valid Response signals for the master.
  output logic                    BREADY,   //! BREADY is HIGH when the master can accept a Response.

  // read request channel
  input  logic                    ARREADY,  //! ARREADY is HIGH when a slave can accept a request.
  output logic                    ARVALID,  //! ARVALID is HIGH when the master holds valid Request signals for a slave.
  output logic [ADDR_WIDTH-1:0]   ARADDR,   //! Holds the address of the first transfer in a Read transaction.
  output burst_type               ARBURST,  //! Describes how the address increments between transfers in a transaction. In this case always Incrimental.
  output logic [7:0]              ARLEN,    //! The total number of transfers in a transaction, encoded as: Length=AxLEN+1. In this case always 7.
  output logic [2:0]              ARSIZE,   //! Indicates the maximum number of bytes in each data transfer within a transaction. In this case always 4.
  output logic [ID_WIDTH-1:0]     ARID,     //! Transaction ID. In this case every master has a fixed ID selected by the ID_SEL parameter.

  // read data channel
  input  logic [DATA_WIDTH-1:0]   RDATA,    //! Read data.
  input  logic                    RLAST,    //! Indicates the last read data transfer of a transaction.
  input  logic [ID_WIDTH-1:0]     RID,      //! Read Response ID.
  input  logic [RESP_WIDTH-1:0]   RRESP,    //! Returns success or failure of the transaction.
  input  logic                    RVALID,   //! RVALID is HIGH when a slave holds valid Response signals for the master.
  output logic                    RREADY    //! RREADY is HIGH when the master can accept a Response.
  //! @end
);

// loop counters
integer i1, i2, i3; //! Loop counter.

////////////////////////////
//    Signal definition   //
////////////////////////////

// structs
//! AW-channel control signals.
struct {
  logic                   pending;
  logic [ADDR_WIDTH-1:0]  addr;
  logic                   valid;
} aw;
//! W-channel control signals.
struct { 
  logic [DATA_WIDTH-1:0] data ;
  logic                  valid;
  logic [NBYTES-1    :0] strb ;
} w;
//! AR-channel control signals.
struct {
  logic                   pending;
  logic [ADDR_WIDTH-1:0]  addr;
  logic                   valid;
} ar;

// AXI related signals
burst_type            burst;  //! Shared Burst type-signal assigned to both AW-channel and AR-channel.
logic [2          :0] size;   //! Shared transfer Size-type signal assigned to both AWSIZE and ARSIZE.
logic [7          :0] len;    //! Shared transaction Length signal assigned to both AWLEN and ARLEN.     
logic [ID_WIDTH-1 :0] id_sel; //! Stores a constant ID for each master depending on the ID_SEL parameter.

// request fifo
logic req_ready;   //! Request-fifo full.
logic req_valid;  //! Request-fifo req_valid.
logic req_push;   //! Request-fifo push.
logic req_pop;    //! Request-fifo pop.
logic [LS_DATA_WIDTH+ADDR_WIDTH+1:0] req_fifo_in; //! Request-fifo data in.
logic [LS_DATA_WIDTH+ADDR_WIDTH+1:0] req_fifo_out; //! Request-fifo data out.

// retrun fifo
logic ret_ready;   //! Return-fifo full signal. 
logic ret_valid;  //! Return-fifo empty signal. 
logic ret_push;   //! Return-fifo push signal. 
logic ret_pop;    //! Return-fifo pop signal.
logic [LS_DATA_WIDTH-1:0] ret_data_in;  //! Return-fifo data in.
logic [LS_DATA_WIDTH-1:0] ret_data_out; //! Return-fifo data out.

// return fifo assist signals
logic [RESP_WIDTH-1:0] resp_keep;     //! Holds the B or R response in case of a double push from both channels. (NOT IMPLEMENTED CORRECTLY)
logic                  ret_push_flag; //! Helps delay the push signal by one cycle.

// word fussion and fission buffers and buffer indexing
logic [DATA_WIDTH-1:0] write_data_buffer [NTRANSF]; //! Stores the incoming 256-bit write data, that later get seperated to 32-bit words for the 8-transfer AXI transactions.
logic [DATA_WIDTH-1:0] read_data_buffer  [NTRANSF]; //! Stores the 8 incoming 32-bit read words to a 256-bit line that gets sent out from the Left-side interface.
logic [LEN_W-1:0] write_index;                      //! Index that helps read the 32-bit words from the write_data_buffer.
logic [LEN_W-1:0] read_index;                       //! Index that helps store the 32-bit words to the read_data_buffer.

////////////////////////////
//    Signal assignment   //
////////////////////////////

// AXI related signals
assign len    = NTRANSF-1;
assign size   = $clog2(NBYTES);
assign burst  = INCR;
assign id_sel = ID_SEL;

// word fussion and fission buffers and buffer indexing
always_ff @( posedge aclk ) begin : Write_index_increment //! - When a WVALID-WREADY handshake takes place, the index is incremented by 1 to read the next word from the write_data_buffer.
  if      (!aresetn)                  write_index <= 0;
  else if (WVALID && WREADY && WLAST) write_index <= 0;
  else if (WVALID && WREADY)          write_index <= write_index + 1;
end

always_ff @( posedge aclk ) begin : Update_write_data_buffer  //! - Checks if the next entry in the Request-fifo is a write request and then it updates the write_data_buffer.
  if (!aresetn) 
    write_data_buffer <= '{default:0};
  else if (req_fifo_out[1:0] == 2'b10 && req_valid && !aw.pending)
    for (i1=0; i1<NTRANSF; i1++)
      write_data_buffer[i1] <= req_fifo_out[(i1*DATA_WIDTH)+ADDR_WIDTH+2+:32];
end

always_ff @( posedge aclk ) begin : Read_index_increment //! - When a RVALID-RREADY handshake takes place, the index is incremented by 1 to store the next word to the read_data_buffer.
  if      (!aresetn)                  read_index <= 0;
  else if (RVALID && RREADY && RLAST) read_index <= 0;
  else if (RVALID && RREADY)          read_index <= read_index + 1;
end

always_ff @( posedge aclk ) begin : Update_read_data_buffer //! - Reads each 32-bit word from the Read data channel and stores them in the read_data_buffer according to the read_index.
  if (!aresetn) read_data_buffer             <= '{default:0};
  else          read_data_buffer[read_index] <= RDATA;
end

// request fifo
always_comb begin : Request_fifo_pop  //! - When a AxVALID-AxREADY handshake takes place, the request-fifo gets popped.
  if      (req_valid && req_fifo_out[1:0]==2'b10 && AWVALID && AWREADY) req_pop = 1;
  else if (req_valid && req_fifo_out[1:0]==2'b01 && ARVALID && ARREADY) req_pop = 1;
  else                                                                   req_pop = 0;
end
assign req_push     = (ls_valid_in && ls_ready_out);
assign req_fifo_in  = {ls_data_in, ls_address, ls_operation};

// return fifo
always_ff @( posedge aclk ) begin : blockName
  if      (!aresetn)                  ret_push <= 0;
  else if (RLAST && RVALID && RREADY) ret_push <= 1;
  else                                ret_push <= 0;
end
always_comb begin : return_fifo_data_in //! - **ret_data_in** gets assigned the comlete **read_data_buffer** word and the **resp_keep** value.
  for (i3=0; i3<NTRANSF; i3++) begin 
    ret_data_in[(i3*DATA_WIDTH)+:DATA_WIDTH] = read_data_buffer[i3];
  end
end
assign ret_pop = ls_valid_out & ls_ready_in;


////////////////////////////
//       Sub-modules      //
////////////////////////////

//! FIFO that stores the incoming requests from the Left-side Interface.
fifo_duth #(
  .DW(LS_DATA_WIDTH+ADDR_WIDTH+2),
  .DEPTH(8)
) request_fifo (
  .clk        (aclk),
  .rst        (!aresetn),
  .push_data  (req_fifo_in),
  .push       (req_push),
  .ready      (req_ready),
  .pop_data   (req_fifo_out),
  .valid      (req_valid),
  .pop        (req_pop)
);

// Return fifo
//! FIFO that stores returning responses and data to send to the Left-side Interface.
fifo_duth # (
  .DW(LS_DATA_WIDTH),
  .DEPTH(8)
) return_fifo (
  .clk        (aclk),
  .rst        (!aresetn),
  .push_data  (ret_data_in),
  .push       (ret_push),
  .ready      (ret_ready),
  .pop_data   (ret_data_out),
  .valid      (ret_valid),
  .pop        (ret_pop)
);


////////////////////////////
//        AXI logic       //
////////////////////////////

// WRITE REQUEST CHANNEL
//! - When **aw.pending** is HIGH, a transaction is taking place.
//! - **aw.addr** holds the address of each transaction and gets assigned to **AWADDR**.
//! - When the next entry in the **request-fifo** is a write request and there is no other transaction taking place, the **aw.pending** signal is raised and the **aw.addr** signal gets updated with the new write transaction address.
//! When the **WLAST** signal is raised to indicate the last transfer of the transaction, the **aw.pending** signal drops to 0.
always_ff @(posedge aclk) begin : awpending_and_awaddr_control 
  if (!aresetn) begin
    aw.pending <= 0;
    aw.addr    <= 0;
  end else if (req_valid && req_fifo_out[1:0]==2'b10 || aw.pending) begin
    aw.pending <= (BVALID && BREADY) ? 0 : 1;
    aw.addr    <= req_fifo_out[ADDR_WIDTH+1:2];
  end
end

//! - The **aw.valid** signal gets assigned to **AWVALID**.
//! - When the next entry in the **request-fifo** is a write request and there is no other pending write transaction, the **aw.valid** signal gets raised.
always_ff @( posedge aclk ) begin : awvalid_control
  if (!aresetn)                                            
    aw.valid <= 0;
  else if (AWVALID && AWREADY)                                  
    aw.valid <= 0;
  else if (req_valid && req_fifo_out[1:0]==2'b10 && !aw.pending && ret_ready)
    aw.valid <= 1;
end

assign AWID     = id_sel;
assign AWADDR   = aw.addr;
assign AWLEN    = len;
assign AWSIZE   = size;
assign AWBURST  = burst;
assign AWVALID  = aw.valid;


// WRITE DATA CHANNEL
//! - The **w.valid** signal gets assigned to **WVALID**.
//! - It gets raised when a **AWVALID**-**AWREADY** handshake takes place and drops when the last transfer of the transaction is writen.
always_ff @( posedge aclk ) begin : wvalid_control
  if (!aresetn) w.valid <= 0;
  else if (WVALID && WREADY && WLAST) w.valid <= 0;
  else if (AWVALID && AWREADY)        w.valid <= 1;
  else if (aw.pending)                w.valid <= w.valid;
end
//! - Initialize **wstrb** with.
always_comb begin 
  for (i2=0; i2<NBYTES; i2++) begin w.strb[i2] = 1; end
end
assign w.data = write_data_buffer[write_index];

assign WVALID   = w.valid;
assign WDATA    = w.data;
assign WSTRB    = w.strb;
assign WLAST    = (write_index == len);


// WRITE RESPONSE CHANNEL
//! - When BVALID is HIGH and the Return-fifo is not full, the **BREADY** signal is raised.
always_ff @(posedge aclk) begin : bready_control
  if      (!aresetn)            BREADY <= 0;
  else if (BVALID && BREADY)    BREADY <= 0;
  else if (BVALID && ret_ready) BREADY <= 1;
end


// READ REQUEST CHANNEL
//! - When **ar.pending** is HIGH, a transaction is taking place.
//! - **ar.addr** holds the address of each transaction and gets assigned to ARADDR.
//! - When the next entry in the Request-fifo is a read request and there is no other transaction taking place, the ar.pending signal is raised and the ar.addr signal gets updated with the new read transaction address.
//! When the RLAST signal is raised to indicate the last transfer of the transaction, the ar.pending signal drops to 0.
always_ff @(posedge aclk) begin : arpending_and_araddr_control
  if (!aresetn) begin
    ar.pending <= 0;
    ar.addr    <= 0;
  end else if (req_valid && req_fifo_out[1:0]==2'b01 || ar.pending) begin
    ar.pending <= (RVALID && RREADY && RLAST) ? 0 : 1;
    ar.addr    <= req_fifo_out[ADDR_WIDTH+1:2];
  end else begin
    ar.pending <= 0;
    ar.addr    <= 0;
  end
end

//! - The **ar.valid** signal gets assigned to ARVALID.
//! - When the next entry in the Request-fifo is a read request and there is no other pending read transaction, the **ar.valid** signal gets raised.
always_ff @( posedge aclk ) begin : arvalid_control
  if (!aresetn)
    ar.valid <= 0;
  else if (ARVALID && ARREADY)                                  
    ar.valid <= 0;
  else if (req_valid && req_fifo_out[1:0]==2'b01 && !ar.pending && ret_ready)
    ar.valid <= 1;
end

assign ARID     = id_sel;
assign ARADDR   = ar.addr;
assign ARLEN    = len;
assign ARSIZE   = size;
assign ARBURST  = burst;
assign ARVALID  = ar.valid;


// READ DATA CHANNEL
//! - When RVALID is HIGH and there is no BVALID signal nor the Return-fifo is full, the **RREADY** signal is raised.
//! It then drops when there is a RVALID-RREADY handshake for the last transfer of the transaction.
always_ff @(posedge aclk) begin : rready_control
  if      (!aresetn)                       RREADY <= 0;
  else if (RVALID && RLAST && RREADY)      RREADY <= 0;
  else if (RVALID && !BVALID && ret_ready) RREADY <= 1;
end


// SIMPLE VALID.READY INTERFACE
assign ls_ready_out = req_ready;
assign ls_valid_out = ret_valid;
assign ls_data_out  = ret_data_out[LS_DATA_WIDTH-1:0];

endmodule