`timescale 1ns/1ps

module s_axi_lite_sim #(
    parameter ADDR_WIDTH   = 32,
    parameter DATA_WIDTH   = 32,
    parameter BYTE_WIDTH   = DATA_WIDTH / 8,
    parameter LOG_BYTE_W   = $clog2(BYTE_WIDTH),

    parameter DEV_SIZE     = 4,
    parameter DEV_ADDR     = $clog2(DEV_SIZE) + LOG_BYTE_W
) (
    // Shared Clock and Sync Active-Low Reset
    input  wire                     aclk,
    input  wire                     aresetn,

    // AXI4-Lite Slave Interface
    input  wire [2:0]               s_axi_awprot,
    input  wire [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire                     s_axi_awvalid,
    output reg                      s_axi_awready,

    input  wire [DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [BYTE_WIDTH-1:0]    s_axi_wstrb,
    input  wire                     s_axi_wvalid,
    output reg                      s_axi_wready,

    output reg  [1:0]               s_axi_bresp,
    output reg                      s_axi_bvalid,
    input  wire                     s_axi_bready,

    input  wire [2:0]               s_axi_arprot,
    input  wire [ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire                     s_axi_arvalid,
    output reg                      s_axi_arready,

    output reg  [DATA_WIDTH-1:0]    s_axi_rdata,
    output reg  [1:0]               s_axi_rresp,
    output reg                      s_axi_rvalid,
    input  wire                     s_axi_rready
);

    // ---------------------------------------------------------------------
    // Internal Memory-mapped Device
    // ---------------------------------------------------------------------

    reg  [DATA_WIDTH-1:0] mm_dev [0:DEV_SIZE-1];
    
//    integer              file_handle;
//    integer              addr_idx;
//    localparam FILENAME   = "simple_boot.hex";
    
    initial begin
//        file_handle = $fopen(FILENAME, "r");
//        for (addr_idx = 0; !$feof(file_handle); addr_idx=addr_idx+1) begin
//            $fscanf(file_handle, "%h", mm_dev[addr_idx]);
//        end
//        $fclose(file_handle);


        // The following is a simple memory copy program
        // to test the PL/DDR memory transactions.
        mm_dev[32'h00][31: 0] = 32'h3c20ff00;
        mm_dev[32'h00][63:32] = 32'h3c405100;
        mm_dev[32'h01][31: 0] = 32'h3940002D;
        mm_dev[32'h01][63:32] = 32'h39600038;
        mm_dev[32'h02][31: 0] = 32'h7c61562a;
        mm_dev[32'h02][63:32] = 32'h7c625fea;
        mm_dev[32'h03][31: 0] = 32'h48000000;
        mm_dev[32'h03][63:32] = 32'h00000000;
        mm_dev[32'h04][31: 0] = 32'hxxxxxxxx;
        mm_dev[32'h04][63:32] = 32'hxxxxxxxx;
        
        mm_dev[32'h05][31: 0] = 32'h33221100;
        mm_dev[32'h05][63:32] = 32'h77665544;
        mm_dev[32'h06][31: 0] = 32'hBBAA9988;
        mm_dev[32'h06][63:32] = 32'hFFEEDDCC;
        
        mm_dev[32'h07][31: 0] = 32'hxxxxxxxx;
        mm_dev[32'h07][63:32] = 32'hxxxxxxxx;
    end

    // ---------------------------------------------------------------------
    // Internal latched storage for AW/W and AR
    // ---------------------------------------------------------------------
    reg  aw_en;                 // address latched flag
    reg  [DEV_ADDR-1:0] awaddr_latched;
    wire [DEV_ADDR-1:LOG_BYTE_W] awaddr_word = awaddr_latched[DEV_ADDR-1:LOG_BYTE_W];

    reg  w_en;                  // data latched flag
    reg  [DATA_WIDTH-1:0] wdata_latched;
    reg  [BYTE_WIDTH-1:0] wstrb_latched;

    reg  ar_en;                 // read address latched flag
    reg  [DEV_ADDR-1:0] araddr_latched;
    wire [DEV_ADDR-1:LOG_BYTE_W] araddr_word = araddr_latched[DEV_ADDR-1:LOG_BYTE_W];

    integer i;

    // ---------------------------------------------------------------------
    // Reset / main sequential logic
    // ---------------------------------------------------------------------
    always @(posedge aclk) begin
        if (!aresetn) begin
            // AXI signals
            s_axi_awready   <= 1'b0;
            s_axi_wready    <= 1'b0;
            s_axi_bvalid    <= 1'b0;
            s_axi_bresp     <= 2'b00;
            s_axi_arready   <= 1'b0;
            s_axi_rvalid    <= 1'b0;
            s_axi_rresp     <= 2'b00;
            s_axi_rdata     <= {DATA_WIDTH{1'b0}};

            // internal latches/flags
            aw_en           <= 1'b0;
            awaddr_latched  <= {DEV_ADDR{1'b0}};
            w_en            <= 1'b0;
            wdata_latched   <= {DATA_WIDTH{1'b0}};
            wstrb_latched   <= {BYTE_WIDTH{1'b0}};
            ar_en           <= 1'b0;
            araddr_latched  <= {DEV_ADDR{1'b0}};
        end else begin
            // default pulse-based ready deassertions
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_arready <= 1'b0;

            // -----------------------------------------------------------------
            // WRITE ADDRESS (AW) acceptance: latch AWADDR when presented
            // -----------------------------------------------------------------
            if (s_axi_awvalid && !aw_en && !s_axi_awready) begin
                // Accept address (pulse s_axi_awready this cycle)
                s_axi_awready   <= 1'b1;
                awaddr_latched  <= s_axi_awaddr[DEV_ADDR-1:0];
                aw_en           <= 1'b1;
            end

            // -----------------------------------------------------------------
            // WRITE DATA (W) acceptance: latch WDATA/WSTRB when presented
            // -----------------------------------------------------------------
            if (s_axi_wvalid && !w_en && !s_axi_wready) begin
                // Accept data (pulse s_axi_wready this cycle)
                s_axi_wready    <= 1'b1;
                wdata_latched   <= s_axi_wdata;
                wstrb_latched   <= s_axi_wstrb;
                w_en            <= 1'b1;
            end

            // -----------------------------------------------------------------
            // When both address AND data latched, perform the register write,
            // then assert BVALID (write response).  Keep BVALID asserted until
            // master accepts it (s_axi_bready).
            // -----------------------------------------------------------------
            if (aw_en && w_en && !s_axi_bvalid) begin
                // decode latched address
                for (i=0; i<BYTE_WIDTH; i=i+1)
                    if (wstrb_latched[i]) mm_dev[awaddr_word][i*8 +: 8] <= wdata_latched[i*8 +: 8];

                // produce write response OKAY
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;

                // clear latched flags (consumed)
                aw_en <= 1'b0;
                w_en  <= 1'b0;
            end

            // Master accepting the write response?
            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end

            // -----------------------------------------------------------------
            // READ ADDRESS (AR) acceptance: latch ARADDR when presented
            // -----------------------------------------------------------------
            if (s_axi_arvalid && !ar_en && !s_axi_arready) begin
                s_axi_arready   <= 1'b1;
                araddr_latched  <= s_axi_araddr[DEV_ADDR-1:0];
                ar_en           <= 1'b1;
            end

            // -----------------------------------------------------------------
            // READ DATA (R) acceptance: produce RDATA/RVALID
            // -----------------------------------------------------------------
            if (ar_en && !s_axi_rvalid) begin
                s_axi_rdata <= mm_dev[araddr_word];
                
                // provide read data and response (OKAY)
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00;
            end

            // Master accepted the read data?
            if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
                ar_en        <= 1'b0;
            end
        end

    end
    
endmodule
