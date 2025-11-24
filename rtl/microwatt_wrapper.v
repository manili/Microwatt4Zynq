/*
 * Verilog Wrapper for the Microwatt Zynq Top-Level VHDL Entity
 *
 * This module serves as a parameter-free wrapper around the VHDL-based
 * `microwatt_zynq_top` entity. This entity is the highest level of the
 * Microwatt subsystem. Its purpose is to be packaged as a Xilinx IP for
 * use in a Vivado Block Design.
 *
 * All generics from the VHDL entity are hardcoded here to sensible defaults for a
 * single-core Microwatt system targeting a Xilinx Zynq UltraScale+ MPSoC.
 *
 * This allows the underlying VHDL to remain configurable while presenting a simple,
 * non-parameterized block in the Vivado Block Design canvas.
 */
`timescale 1ns/1ps

module microwatt_wrapper #(
    parameter ADDR_WIDTH   = 32,
    parameter DATA_WIDTH   = 64,
    parameter BYTE_WIDTH   = DATA_WIDTH / 8,
    parameter LOG_BYTE_W   = $clog2(BYTE_WIDTH),
    parameter WBS_ADDR_LSB = $clog2(BYTE_WIDTH),

    parameter S_AXI_DATA_WIDTH = 32,
    parameter S_AXI_BYTE_WIDTH = S_AXI_DATA_WIDTH / 8
) (
    // AXI Clock and Active-Low Reset
    input wire                          aclk,
    input wire                          aresetn,
    
    // Interrupt Input from Zynq PS
    input wire                          ext_irq_uart0,
    input wire                          ext_irq_eth,
    input wire                          ext_irq_sdcard,

    // AXI4-Lite Slave Interface
    input  wire [2:0]                   s_axi_awprot,
    input  wire [ADDR_WIDTH-1:0]        s_axi_awaddr,
    input  wire                         s_axi_awvalid,
    output wire                         s_axi_awready,

    input  wire [S_AXI_DATA_WIDTH-1:0]  s_axi_wdata,
    input  wire [S_AXI_BYTE_WIDTH-1:0]  s_axi_wstrb,
    input  wire                         s_axi_wvalid,
    output wire                         s_axi_wready,

    output wire [1:0]                   s_axi_bresp,
    output wire                         s_axi_bvalid,
    input  wire                         s_axi_bready,

    input  wire [2:0]                   s_axi_arprot,
    input  wire [ADDR_WIDTH-1:0]        s_axi_araddr,
    input  wire                         s_axi_arvalid,
    output wire                         s_axi_arready,

    output wire [S_AXI_DATA_WIDTH-1:0]  s_axi_rdata,
    output wire [1:0]                   s_axi_rresp,
    output wire                         s_axi_rvalid,
    input  wire                         s_axi_rready,

    // AXI4-Lite Master Interface
    output wire [2:0]                   m_axi_awprot,
    output wire                         m_axi_awvalid,
    output wire [ADDR_WIDTH-1:0]        m_axi_awaddr,
    input  wire                         m_axi_awready,
    
    output wire                         m_axi_wvalid,
    output wire [DATA_WIDTH-1:0]        m_axi_wdata,
    output wire [BYTE_WIDTH-1:0]        m_axi_wstrb,
    input  wire                         m_axi_wready,
    
    input  wire                         m_axi_bvalid,
    input  wire [1:0]                   m_axi_bresp,
    output wire                         m_axi_bready,
    
    output wire [2:0]                   m_axi_arprot,
    output wire                         m_axi_arvalid,
    output wire [ADDR_WIDTH-1:0]        m_axi_araddr,
    input  wire                         m_axi_arready,
    
    input  wire                         m_axi_rvalid,
    input  wire [DATA_WIDTH-1:0]        m_axi_rdata,
    input  wire [1:0]                   m_axi_rresp,
    output wire                         m_axi_rready
);

    wire [S_AXI_DATA_WIDTH-1:0] slv_reg0; // Control Register, slv_reg0[0] -> System Reset
    wire [S_AXI_DATA_WIDTH-1:0] slv_reg1; // DRAM address offset
    wire [S_AXI_DATA_WIDTH-1:0] slv_reg2; // Reserved
    wire [S_AXI_DATA_WIDTH-1:0] slv_reg3; // Versioning

    wire mw_aresetn;
    wire [ADDR_WIDTH-1:0] mw_m_axi_awaddr;
    wire [ADDR_WIDTH-1:0] mw_m_axi_araddr;
    
    assign mw_aresetn = aresetn & slv_reg0[0];
    // Don't use "(DRAM_SIZE > mw_m_axi_aXaddr + slv_reg1) ? ..."
    // This would cause addition overflow and needs 33 bits instead of 32.
    localparam DRAM_SIZE = 32'h8000_0000;
    assign m_axi_awaddr = (DRAM_SIZE - slv_reg1 > mw_m_axi_awaddr) ? mw_m_axi_awaddr + slv_reg1 : mw_m_axi_awaddr;
    assign m_axi_araddr = (DRAM_SIZE - slv_reg1 > mw_m_axi_araddr) ? mw_m_axi_araddr + slv_reg1 : mw_m_axi_araddr;

    // Zynq's PS to PL Connection for Controlling and Debugging Purposes
    s_axi_lite #(
        .ADDR_WIDTH     (ADDR_WIDTH         ),
        .DATA_WIDTH     (S_AXI_DATA_WIDTH   )
    ) s_axi_lite_inst (
        .slv_reg0       (slv_reg0           ),
        .slv_reg1       (slv_reg1           ),
        .slv_reg2       (slv_reg2           ),
        .slv_reg3       (slv_reg3           ),

        .aclk           (aclk               ),
        .aresetn        (aresetn            ),
        .s_axi_awaddr   (s_axi_awaddr       ),
        .s_axi_awprot   (s_axi_awprot       ),
        .s_axi_awvalid  (s_axi_awvalid      ),
        .s_axi_awready  (s_axi_awready      ),
        .s_axi_wdata    (s_axi_wdata        ),
        .s_axi_wstrb    (s_axi_wstrb        ),
        .s_axi_wvalid   (s_axi_wvalid       ),
        .s_axi_wready   (s_axi_wready       ),
        .s_axi_bresp    (s_axi_bresp        ),
        .s_axi_bvalid   (s_axi_bvalid       ),
        .s_axi_bready   (s_axi_bready       ),
        .s_axi_araddr   (s_axi_araddr       ),
        .s_axi_arprot   (s_axi_arprot       ),
        .s_axi_arvalid  (s_axi_arvalid      ),
        .s_axi_arready  (s_axi_arready      ),
        .s_axi_rdata    (s_axi_rdata        ),
        .s_axi_rresp    (s_axi_rresp        ),
        .s_axi_rvalid   (s_axi_rvalid       ),
        .s_axi_rready   (s_axi_rready       )
    );

    // Instantiation of the VHDL `microwatt_zynq_top` entity.
    // All generics are hardcoded here.
    microwatt_zynq_top microwatt_zynq_top_inst (
        .aclk           (aclk               ),
        .aresetn        (mw_aresetn         ),
        .ext_irq_uart0  (ext_irq_uart0      ),
        .ext_irq_eth    (ext_irq_eth        ),
        .ext_irq_sdcard (ext_irq_sdcard     ),
        .m_axi_awprot   (m_axi_awprot       ),
        .m_axi_awvalid  (m_axi_awvalid      ),
        .m_axi_awaddr   (mw_m_axi_awaddr    ),
        .m_axi_awready  (m_axi_awready      ),
        .m_axi_wvalid   (m_axi_wvalid       ),
        .m_axi_wdata    (m_axi_wdata        ),
        .m_axi_wstrb    (m_axi_wstrb        ),
        .m_axi_wready   (m_axi_wready       ),
        .m_axi_bvalid   (m_axi_bvalid       ),
        .m_axi_bresp    (m_axi_bresp        ),
        .m_axi_bready   (m_axi_bready       ),
        .m_axi_arprot   (m_axi_arprot       ),
        .m_axi_arvalid  (m_axi_arvalid      ),
        .m_axi_araddr   (mw_m_axi_araddr    ),
        .m_axi_arready  (m_axi_arready      ),
        .m_axi_rvalid   (m_axi_rvalid       ),
        .m_axi_rdata    (m_axi_rdata        ),
        .m_axi_rresp    (m_axi_rresp        ),
        .m_axi_rready   (m_axi_rready       )
    );

endmodule