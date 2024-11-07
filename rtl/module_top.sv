/**
*@info top module
*@info Sub-Modules: processor_top.sv, main_memory.sv
*
*
* @brief Initializes the Processor and the main memory controller, and connects them
*
*/
`ifdef MODEL_TECH
    `include "structs.sv"
`endif
module module_top (
    input logic clk  ,
    input logic rst_n
);
    //Memory System Parameters
    localparam IC_ENTRIES   = 32  ;
    localparam IC_DW        = 256 ;
    localparam DC_ENTRIES   = 32  ;
    localparam DC_DW        = 256 ;
    localparam L2_ENTRIES   = 1900000;
    localparam L2_DW        = 512 ;
    localparam REALISTIC    = 1   ;
    localparam DELAY_CYCLES = 10  ;
    //Predictor Parameters
    localparam RAS_DEPTH        = 8  ;
    localparam GSH_HISTORY_BITS = 2  ;
    localparam GSH_SIZE         = 256;
    localparam BTB_SIZE         = 256;
    //Dual Issue Enabler
    localparam DUAL_ISSUE = 1;
    //ROB Parameters    (Do NOT MODIFY, structs cannot update their widths automatically)
    localparam ROB_ENTRIES  = 8                  ; //default: 8
    localparam ROB_TICKET_W = $clog2(ROB_ENTRIES); //default: DO NOT MODIFY
    //Other Parameters  (DO NOT MODIFY)
    localparam ISTR_DW        = 32        ; //default: 32
    localparam ADDR_BITS      = 32        ; //default: 32
    localparam DATA_WIDTH     = 32        ; //default: 32
    localparam R_WIDTH        = 6         ; //default: 6
    localparam MICROOP_W      = 5         ; //default: 5
    localparam UNCACHEABLE_ST = 4294901760; //default: 4294901760
    //===================================================================================
    logic                        icache_valid_i, dcache_valid_i, cache_store_valid, icache_valid_o, dcache_valid_o, cache_load_valid, write_l2_valid;
    logic     [   ADDR_BITS-1:0] icache_address_i, dcache_address_i, cache_store_addr, icache_address_o, dcache_address_o, write_l2_addr_c, write_l2_addr, cache_load_addr;
    logic     [       DC_DW-1:0] write_l2_data, write_l2_data_c, dcache_data_o;
    logic     [  DATA_WIDTH-1:0] cache_store_data    ;
    logic     [       IC_DW-1:0] icache_data_o       ;
    logic     [   ADDR_BITS-1:0] current_pc          ;
    logic                        hit_icache, miss_icache, half_fetch;
    logic     [     ISTR_DW-1:0] fetched_data        ;
    logic                        cache_store_uncached, cache_store_cached, write_l2_valid_c;
    logic     [     R_WIDTH-1:0] cache_load_dest     ;
    logic     [   MICROOP_W-1:0] cache_load_microop, cache_store_microop;
    logic     [ROB_TICKET_W-1:0] cache_load_ticket   ;
    ex_update                    cache_fu_update     ;

    logic        frame_buffer_write  ;
    logic [15:0] frame_buffer_data   ;
    logic [14:0] frame_buffer_address;
    logic [ 7:0] red_o, green_o, blue_o;
    logic [ 4:0] color               ;

    logic                  ic_inactive_valid_o;
    logic [ADDR_BITS-1:0]  ic_inactive_addr_o;
    logic [IC_DW-1:0]      ic_inactive_data_o;

    logic                  ic_AXI_AWVALID, dc_AXI_AWVALID;
    logic                  ic_AXI_AWREADY, dc_AXI_AWREADY;
    logic [ADDR_BITS-1 :0] ic_AXI_AWADDR , dc_AXI_AWADDR ;
    burst_type             ic_AXI_AWBURST, dc_AXI_AWBURST;
    logic [7           :0] ic_AXI_AWLEN  , dc_AXI_AWLEN  ;
    logic [2           :0] ic_AXI_AWSIZE , dc_AXI_AWSIZE ;
    logic [3           :0] ic_AXI_AWID   , dc_AXI_AWID   ;
    logic                  ic_AXI_WVALID , dc_AXI_WVALID ;
    logic                  ic_AXI_WREADY , dc_AXI_WREADY ;
    logic [DATA_WIDTH-1:0] ic_AXI_WDATA  , dc_AXI_WDATA  ;
    logic                  ic_AXI_WLAST  , dc_AXI_WLAST  ;
    logic [3           :0] ic_AXI_WSTRB  , dc_AXI_WSTRB  ;
    logic [3           :0] ic_AXI_BID    , dc_AXI_BID    ;
    logic [1           :0] ic_AXI_BRESP  , dc_AXI_BRESP  ;
    logic                  ic_AXI_BVALID , dc_AXI_BVALID ;
    logic                  ic_AXI_BREADY , dc_AXI_BREADY ;
    logic                  ic_AXI_ARREADY, dc_AXI_ARREADY;
    logic                  ic_AXI_ARVALID, dc_AXI_ARVALID;
    logic [ADDR_BITS-1 :0] ic_AXI_ARADDR , dc_AXI_ARADDR ;
    burst_type             ic_AXI_ARBURST, dc_AXI_ARBURST;
    logic [7           :0] ic_AXI_ARLEN  , dc_AXI_ARLEN  ;
    logic [2           :0] ic_AXI_ARSIZE , dc_AXI_ARSIZE ;
    logic [3           :0] ic_AXI_ARID   , dc_AXI_ARID   ;
    logic [DATA_WIDTH-1:0] ic_AXI_RDATA  , dc_AXI_RDATA  ;
    logic                  ic_AXI_RLAST  , dc_AXI_RLAST  ;
    logic [3           :0] ic_AXI_RID    , dc_AXI_RID    ;
    logic [1           :0] ic_AXI_RRESP  , dc_AXI_RRESP  ;
    logic                  ic_AXI_RVALID , dc_AXI_RVALID ;
    logic                  ic_AXI_RREADY , dc_AXI_RREADY ;


    //////////////////////////////////////////////////
    //                   Processor                  //
    //////////////////////////////////////////////////
    processor_top #(
        .ADDR_BITS       (ADDR_BITS       ),
        .INSTR_BITS      (ISTR_DW         ),
        .DATA_WIDTH      (DATA_WIDTH      ),
        .MICROOP_WIDTH   (5               ),
        .PR_WIDTH        (R_WIDTH         ),
        .ROB_ENTRIES     (ROB_ENTRIES     ),
        .RAS_DEPTH       (RAS_DEPTH       ),
        .GSH_HISTORY_BITS(GSH_HISTORY_BITS),
        .GSH_SIZE        (GSH_SIZE        ),
        .BTB_SIZE        (BTB_SIZE        ),
        .DUAL_ISSUE      (DUAL_ISSUE      ),
        .MAX_BRANCH_IF   (4               )
    ) top_processor (
        .clk               (clk                ),
        .rst_n             (rst_n              ),
        //Input from ICache
        .current_pc        (current_pc         ),
        .hit_icache        (hit_icache         ),
        .miss_icache       (miss_icache        ),
        .half_fetch        (half_fetch         ),
        .fetched_data      (fetched_data       ),
        // Writeback into DCache (stores)
        .cache_wb_valid_o  (cache_store_valid  ),
        .cache_wb_addr_o   (cache_store_addr   ),
        .cache_wb_data_o   (cache_store_data   ),
        .cache_wb_microop_o(cache_store_microop),
        // Load for DCache
        .cache_load_valid  (cache_load_valid   ),
        .cache_load_addr   (cache_load_addr    ),
        .cache_load_dest   (cache_load_dest    ),
        .cache_load_microop(cache_load_microop ),
        .cache_load_ticket (cache_load_ticket  ),
        //Misc
        .cache_fu_update   (cache_fu_update    ),
        .cache_blocked     (cache_blocked      ),
        .cache_will_block  (cache_will_block   ),
        .ld_st_output_used (ld_st_output_used  )
    );
    //Check for new store if cached/uncached and drive it into the cache
    assign cache_store_uncached = cache_store_valid & (cache_store_addr>=UNCACHEABLE_ST);
    assign cache_store_cached   = cache_store_valid & ~cache_store_uncached;
    //Create the Signals for the write-through into the L2
    assign write_l2_valid   = cache_store_uncached | write_l2_valid_c;
    assign write_l2_addr    = cache_store_uncached ? cache_store_addr : write_l2_addr_c;
    assign write_l2_data    = cache_store_uncached ? cache_store_data : write_l2_data_c;
    // assign write_l2_microop = cache_store_uncached ? cache_store_microop : 5'b0;

    assign frame_buffer_write   = cache_store_uncached;
    assign frame_buffer_data    = cache_store_data[15:0];
    assign frame_buffer_address = cache_store_addr[14:0];
    assign color                = cache_store_data[4:0];

    logic [15:0] frame_buffer[19200-1:0];
    always_ff @(posedge clk) begin : FB
        if(frame_buffer_write) begin
            frame_buffer[frame_buffer_address] = frame_buffer_data;
        end
    end
    //////////////////////////////////////////////////
    //               Main Memory Module             //
    //////////////////////////////////////////////////
    main_memory_top # (
        .USE_AXI                (0),
        .L2_BLOCK_DW            (L2_DW),
        .L2_ENTRIES             (L2_ENTRIES),
        .ADDRESS_BITS           (ADDR_BITS),
        .ICACHE_BLOCK_DW        (IC_DW),
        .DCACHE_BLOCK_DW        (DC_DW),
        .REALISTIC              (REALISTIC),
        .DELAY_CYCLES           (DELAY_CYCLES),
        .FILE_NAME              ("memory.mem"),
        .ID_W                   (4),
        .ADDR_W                 (32),
        .AXI_DW                 (32),
        .RESP_W                 (2)
    ) main_memory_top (
        .clk_i                  (clk),
        .rst_n_i                (rst_n),
        // icache
        .icache_valid_i         (icache_valid_i),
        .icache_address_i       (icache_address_i),
        .icache_valid_o         (icache_valid_o),
        .icache_data_o          (icache_data_o),
        // Request Write Port to L2
        .write_l2_valid         (write_l2_valid),
        .write_l2_addr          (write_l2_addr),
        .write_l2_data          (write_l2_data),
        // Request Read Port to L2
        .dcache_valid_i         (dcache_valid_i),
        .dcache_address_i       (dcache_address_i),
        // Update Port from L2
        .dcache_valid_o         (dcache_valid_o),
        .dcache_address_o       (dcache_address_o),
        .dcache_data_o          (dcache_data_o)
    );

    
    /////////////////////////////////////////////////
    //               Caches' Subsection            //
    /////////////////////////////////////////////////
    cache_top # (
        .USE_AXI                (0),
        .ADDR_BITS              (ADDR_BITS),
        .ISTR_DW                (ISTR_DW),
        .DATA_WIDTH             (DATA_WIDTH),
        .R_WIDTH                (R_WIDTH),
        .MICROOP_W              (MICROOP_W),
        .ROB_ENTRIES            (ROB_ENTRIES),
        .IC_ENTRIES             (IC_ENTRIES),
        .DC_ENTRIES             (DC_ENTRIES),
        .IC_DW                  (IC_DW),
        .DC_DW                  (DC_DW),
        .AXI_AW                 (32),
        .AXI_DW                 (32)
    ) caches_top (
        .clk                    (clk),
        .resetn                 (rst_n),

        .icache_current_pc      (current_pc),
        .icache_hit_icache      (hit_icache),
        .icache_miss_icache     (miss_icache),
        .icache_half_fetch      (half_fetch),
        .icache_instruction_out (fetched_data),
        .dcache_output_used     (ld_st_output_used),
        .dcache_load_valid      (cache_load_valid),
        .dcache_load_address    (cache_load_addr),
        .dcache_load_dest       (cache_load_dest),
        .dcache_load_microop    (cache_load_microop),
        .dcache_load_ticket     (cache_load_ticket),
        .dcache_store_valid     (cache_store_cached),
        .dcache_store_address   (cache_store_addr),
        .dcache_store_data      (cache_store_data),
        .dcache_store_microop   (cache_store_microop),
        .dcache_will_block      (cache_will_block),
        .dcache_blocked         (cache_blocked),
        .dcache_served_output   (cache_fu_update),

        // icache
        .valid_out              (icache_valid_i),
        .address_out            (icache_address_i),
        .ready_in               (icache_valid_o),
        .data_in                (icache_data_o),
        // Request Write Port to L2
        .write_l2_valid         (write_l2_valid_c),
        .write_l2_addr          (write_l2_addr_c),
        .write_l2_data          (write_l2_data_c),
        // Request Read Port to L2
        .request_l2_valid       (dcache_valid_i),
        .request_l2_addr        (dcache_address_i),
        // Update Port from L2
        .update_l2_valid        (dcache_valid_o),
        .update_l2_addr         (dcache_address_o),
        .update_l2_data         (dcache_data_o)
    );

    //=====================================================================
    logic [14:0] vga_address;
    logic [15:0] vga_data;
    logic hsync, vsync, vga_clk;

    assign vga_data = frame_buffer[vga_address];

    vga_controller vga_controller (
        .clk    (clk        ),
        .rst_n  (rst_n      ),
        //read
        .valid_o(           ),
        .address(vga_address),
        .data_in(vga_data   ),
        //output
        .hsync  (hsync      ),
        .vsync  (vsync      ),
        .vga_clk(vga_clk    ),
        .red_o  (red_o      ),
        .green_o(green_o    ),
        .blue_o (blue_o     )
    );

endmodule : module_top