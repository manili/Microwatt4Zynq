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
 * Module: s_wb_2_m_axi_lite
 *
 * Description:
 *   A parameterized bridge from a Wishbone B4 Classic slave interface to an
 *   AXI4-Lite master interface. This module allows a Wishbone master (e.g., a
 *   soft-core CPU) to access an AXI4-Lite slave (e.g., peripherals in a Zynq PS).
 *
 *   MODIFICATIONS in this version:
 *   - Stalling: Uses a delayed 's_wb_ack' to implicitly stall the Wishbone
 *     master. The 's_wb_stall' signal is tied low.
 *   - Addressing: Assumes Wishbone word addressing.
 *   - Reset: Uses an active-low synchronous reset.
 *
 *   - Wishbone B4 Classic Slave: The bridge acts as a slave, responding to
 *     requests from a Wishbone master. It supports single-beat transactions.
 *
 *   - AXI4-Lite Master: The bridge acts as a master, initiating AXI4-Lite read
 *     and write transactions. It adheres to AXI4-Lite rules (single beat).
 *
 *   - FSM: A unified finite-state machine handles both read and write operations,
 *     ensuring in-order transaction processing.
 *
 *   - Error Handling: AXI error responses (SLVERR/DECERR) are handled by
 *     completing the Wishbone cycle with an ACK, per the Wishbone spec.
 */

module s_wb_2_m_axi_lite #(
    parameter ADDR_WIDTH   = 32,
    parameter DATA_WIDTH   = 64,
    parameter BYTE_WIDTH   = DATA_WIDTH / 8,
    parameter WBS_ADDR_LSB = $clog2(BYTE_WIDTH)
) (
    // Shared clock and reset
    input  wire                  aclk,          // Sync Clock
    input  wire                  aresetn,       // Active-Low Sync Reset

    // Wishbone B4 Classic Slave interface (Microwatt as master)
    input  wire                  s_wb_cyc,      // cycle valid
    input  wire                  s_wb_stb,      // strobe/request
    input  wire                  s_wb_we,       // 1=write, 0=read
    input  wire [ADDR_WIDTH-1:WBS_ADDR_LSB] s_wb_adr, // word address (no byte offset bits)
    input  wire [DATA_WIDTH-1:0] s_wb_dat_i,    // write data from master
    input  wire [BYTE_WIDTH-1:0] s_wb_sel,      // byte-enable/byte select

    output reg  [DATA_WIDTH-1:0] s_wb_dat_o,    // read data to master
    output reg                   s_wb_ack,      // 1-cycle ack (or error) response
    output reg                   s_wb_stall,    // stall to throttle/master back-pressure

    // AXI4-Lite Master interface to PS (assumed 32/64-bit data)
    // Write Address Channel
    output reg  [2:0]            m_axi_awprot,  // write address protection
    output reg                   m_axi_awvalid, // write address valid
    output reg  [ADDR_WIDTH-1:0] m_axi_awaddr,  // write address
    input  wire                  m_axi_awready, // write address ready

    // Write Data Channel
    output reg                   m_axi_wvalid,  // write data valid
    output reg  [DATA_WIDTH-1:0] m_axi_wdata,   // write data
    output reg  [BYTE_WIDTH-1:0] m_axi_wstrb,   // write strobes
    input  wire                  m_axi_wready,  // write data ready

    // Write Response Channel
    input  wire                  m_axi_bvalid,  // write response valid
    input  wire [1:0]            m_axi_bresp,   // write response
    output reg                   m_axi_bready,  // write response ready

    // Read Address Channel
    output reg  [2:0]            m_axi_arprot,  // read address protection
    output reg                   m_axi_arvalid, // read address valid
    output reg  [ADDR_WIDTH-1:0] m_axi_araddr,  // read address
    input  wire                  m_axi_arready, // read address ready

    // Read Data Channel
    input  wire                  m_axi_rvalid,  // read data valid
    input  wire [DATA_WIDTH-1:0] m_axi_rdata,   // read data
    input  wire [1:0]            m_axi_rresp,   // read response
    output reg                   m_axi_rready   // read data ready
);

    //--------------------------------------------------------------------------
    // Definitions and Parameters
    //--------------------------------------------------------------------------

    // WB4 Local Params
    localparam [1:0] WB_S_IDLE = 2'b00;
    localparam [1:0] WB_S_WAIT = 2'b01;
    localparam [1:0] WB_S_DONE = 2'b10;

    // AXI4 Local Params
    localparam [1:0] AXI_S_IDLE  = 2'b00;
    localparam [1:0] AXI_S_WRITE = 2'b01;
    localparam [1:0] AXI_S_READ  = 2'b10;

    // WB4 FSM Internal Signals
    reg [1:0] wb_state;

    reg axi_start;
    reg axi_we;
    reg [ADDR_WIDTH-1:0] axi_addr;
    reg [DATA_WIDTH-1:0] axi_wdata;
    reg [BYTE_WIDTH-1:0] axi_wstrb;

    // AXI4 FSM Internal Signals
    reg [1:0] axi_state;

    reg axi_done;
    reg axi_resp_err;
    reg [1:0] axi_resp_code;
    reg [DATA_WIDTH-1:0] axi_rdata;

    // Default protection bits (normal, non-secure, data access)
    wire [2:0] DEF_PROT = 3'b000;

    //--------------------------------------------------------------------------
    // Wishbone 4 Classic Slave
    //--------------------------------------------------------------------------

    always @(*) begin
        if (!aresetn) begin
            s_wb_stall  <= 1'b0;
        end else begin
            if (s_wb_cyc && s_wb_stb)
                s_wb_stall  <= !s_wb_ack;
            else
                s_wb_stall  <= 1'b0;
        end
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            // reset all registers
            wb_state    <= WB_S_IDLE;
            s_wb_dat_o  <= {DATA_WIDTH{1'b0}};
            s_wb_ack    <= 1'b0;

            axi_start   <= 1'b0;
            axi_we      <= 1'b0;
            axi_addr    <= {ADDR_WIDTH{1'b0}};
            axi_wdata   <= {DATA_WIDTH{1'b0}};
            axi_wstrb   <= {BYTE_WIDTH{1'b0}};
        end else begin
            case (wb_state)
                WB_S_IDLE: begin
                    // Default: not stalling
                    s_wb_ack   <= 1'b0;

                    // Accept request only if master asserts cyc & stb and we are not already acknoledged it
                    if (s_wb_cyc && s_wb_stb && !s_wb_ack) begin
                        // assert stall while waiting for response (prevents master from issuing new request)
                        axi_start   <= 1'b1;
                        axi_we      <= s_wb_we;
                        axi_addr    <= { s_wb_adr, {WBS_ADDR_LSB{1'b0}} }; // convert word address -> byte address
                        axi_wdata   <= s_wb_dat_i;
                        axi_wstrb   <= s_wb_sel;

                        // Now wait for the AXI bus to finish and assert axi_done
                        wb_state <= WB_S_WAIT;
                    end
                end

                WB_S_WAIT: begin
                    // Wait for AXI bus to indicate transaction is done
                    axi_start <= 1'b0;

                    if (axi_done) begin
                        if (!axi_we) begin
                            // capture response and return the aligned data to the wb_master
                            s_wb_dat_o <= axi_rdata;
                        end

                        // after returning ack, go back to IDLE and allow next transfer
                        s_wb_ack <= 1'b1;
                        wb_state <= WB_S_IDLE;
                    end
                end

                default: begin
                    wb_state <= WB_S_IDLE;
                end
            endcase
        end
    end

    //--------------------------------------------------------------------------
    // AXI 4 Lite Master
    //--------------------------------------------------------------------------

    always @(posedge aclk) begin
        if (!aresetn) begin
            // Reset (active-low)
            axi_state       <= AXI_S_IDLE;

            axi_done        <= 1'b0;
            axi_rdata       <= {DATA_WIDTH{1'b0}};
            axi_resp_err    <= 1'b0;
            axi_resp_code   <= 2'b00;

            m_axi_awvalid   <= 1'b0;
            m_axi_wvalid    <= 1'b0;
            m_axi_bready    <= 1'b0;
            m_axi_arvalid   <= 1'b0;
            m_axi_rready    <= 1'b0;
            m_axi_awaddr    <= {ADDR_WIDTH{1'b0}};
            m_axi_wdata     <= {ADDR_WIDTH{1'b0}};
            m_axi_wstrb     <= {BYTE_WIDTH{1'b0}};
            m_axi_araddr    <= {ADDR_WIDTH{1'b0}};
            m_axi_awprot    <= DEF_PROT;
            m_axi_arprot    <= DEF_PROT;
        end else begin
            case (axi_state)
                AXI_S_IDLE: begin
                    axi_done <= 1'b0;

                    // Wait for a axi_start pulse
                    if (axi_start) begin
                        if (axi_we) begin
                            // Capture write information and assert m_axi_awvalid/m_axi_wvalid
                            m_axi_awaddr  <= axi_addr;
                            m_axi_wdata   <= axi_wdata;
                            m_axi_wstrb   <= axi_wstrb;
                            m_axi_awvalid <= 1'b1;
                            m_axi_wvalid  <= 1'b1;
                            m_axi_bready  <= 1'b1;    // be ready to accept write response
                            axi_state   <= AXI_S_WRITE;
                        end else begin
                            // Read transaction
                            m_axi_araddr  <= axi_addr;
                            m_axi_arvalid <= 1'b1;
                            m_axi_rready  <= 1'b1;
                            axi_state   <= AXI_S_READ;
                        end
                    end
                end

                AXI_S_WRITE: begin
                    // Deassert m_axi_awvalid/m_axi_wvalid when accepted
                    if (m_axi_awvalid && m_axi_awready) m_axi_awvalid <= 1'b0;
                    if (m_axi_wvalid  && m_axi_wready)  m_axi_wvalid  <= 1'b0;

                    // When slave asserts m_axi_bvalid, sample m_axi_bresp, flag error if != OKAY
                    if (m_axi_bvalid) begin
                        m_axi_bready    <= 1'b0;

                        axi_resp_code   <= m_axi_bresp;
                        axi_resp_err    <= (m_axi_bresp != 2'b00);
                        axi_done        <= 1'b1;
                        axi_state       <= AXI_S_IDLE;
                    end
                end

                AXI_S_READ: begin
                    if (m_axi_arvalid && m_axi_arready) m_axi_arvalid <= 1'b0;

                    // When slave asserts m_axi_rvalid, sample data and m_axi_rresp
                    if (m_axi_rvalid) begin
                        m_axi_rready    <= 1'b0;

                        axi_rdata       <= m_axi_rdata;
                        axi_resp_code   <= m_axi_rresp;
                        axi_resp_err    <= (m_axi_rresp != 2'b00);
                        axi_done        <= 1'b1;
                        axi_state       <= AXI_S_IDLE;
                    end
                end

                default: axi_state <= AXI_S_IDLE;
            endcase
        end
    end

endmodule