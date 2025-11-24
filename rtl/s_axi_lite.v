/*
 * Copyright 2025 Mohammad A. Nili
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * Module: s_axi_lite
 *
 * Description:
 *   Fixed AXI4-Lite slave
 *   - Latches AWADDR and WDATA/WSTRB separately and performs the write only
 *     when both address and data have been accepted (handles either order).
 *   - Proper read address latching.
 *   - Active-low synchronous reset (aresetn).
 *   - Single-beat AXI-Lite only.
 */
`timescale 1ns/1ps

module s_axi_lite #(
    parameter ADDR_WIDTH   = 32,
    parameter DATA_WIDTH   = 32,
    parameter BYTE_WIDTH   = DATA_WIDTH / 8,
    parameter WBS_ADDR_LSB = $clog2(BYTE_WIDTH),

    parameter DEV_SIZE     = 4,
    parameter DEV_ADDR     = $clog2(DEV_SIZE) + WBS_ADDR_LSB
) (
    // User register interface
    output wire [DATA_WIDTH-1:0]    slv_reg0,       // Control Register
    output wire [DATA_WIDTH-1:0]    slv_reg1,       // DRAM Base Address
    output wire [DATA_WIDTH-1:0]    slv_reg2,       // Reserved
    output wire [DATA_WIDTH-1:0]    slv_reg3,       // Versioning
    
    // Shared clock and reset
    input  wire                     aclk,
    input  wire                     aresetn,        // active-low synchronous reset

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
    
    assign slv_reg0 = mm_dev[0];
    assign slv_reg1 = mm_dev[1];
    assign slv_reg2 = mm_dev[2];
    assign slv_reg3 = mm_dev[3];

    // ---------------------------------------------------------------------
    // Internal latched storage for AW/W and AR
    // ---------------------------------------------------------------------
    reg  aw_en;                 // address latched flag
    reg  [DEV_ADDR-1:0] awaddr_latched;
    wire [DEV_ADDR-WBS_ADDR_LSB-1:0] awaddr_word = awaddr_latched >> WBS_ADDR_LSB;

    reg  w_en;                  // data latched flag
    reg  [DATA_WIDTH-1:0] wdata_latched;
    reg  [BYTE_WIDTH-1:0] wstrb_latched;

    reg  ar_en;                 // read address latched flag
    reg  [DEV_ADDR-1:0] araddr_latched;
    wire [DEV_ADDR-WBS_ADDR_LSB-1:0] araddr_word = araddr_latched >> WBS_ADDR_LSB;

    integer i;

    // ---------------------------------------------------------------------
    // Reset / main sequential logic
    // ---------------------------------------------------------------------
    always @(posedge aclk) begin
        if (!aresetn) begin
            // Internal Registers
            mm_dev[0] <= {DATA_WIDTH{1'b0}};
            mm_dev[1] <= {DATA_WIDTH{1'b0}};
            mm_dev[2] <= {DATA_WIDTH{1'b0}};
            mm_dev[3] <= 32'hDEADBEEF;
        
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
                // decode latched address (word-aligned: [3:2] selects reg)
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
                if (araddr_word == 3'h3)
                    s_axi_rdata <= slv_reg3;
                else
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