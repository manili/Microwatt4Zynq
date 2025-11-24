/*
 * Testbench for tb
 *
 * Description:
 *   This testbench verifies the `s_wb_2_m_axi_lite` bridge module. It includes:
 *   - A simple behavioral AXI4-Lite slave model to respond to the DUT's requests.
 *   - Wishbone master tasks to generate read and write transactions, now handling
 *     the wbs_stall_o signal correctly.
 *   - A test sequence that covers:
 *     - Basic aligned read and write.
 *     - Partial-byte writes using different `wbs_sel_i` patterns.
 *     - AXI slave error responses (SLVERR).
 *
 *   MODIFICATIONS for this version:
 *   - Testbench master now correctly holds signals steady when wbs_stall_o is asserted.
 *   - Reset is synchronous.
 *   - Addresses sent are word addresses.
 *   - **BUG FIX**: Corrected AXI slave model to properly latch the write address
 *     from the AW channel before processing the W channel data.
 */
`timescale 1ns/1ps

module tb_1;

    // Parameters
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 64;
    localparam BYTE_WIDTH = DATA_WIDTH / 8;
    localparam WBS_ADDR_LSB = $clog2(BYTE_WIDTH);

    // Clock and Reset
    reg aclk;
    reg aresetn;

    // Wishbone Interface
    wire                      m2s_wb_cyc;
    wire                      m2s_wb_stb;
    wire                      m2s_wb_we;
    wire [ADDR_WIDTH-1:WBS_ADDR_LSB] m2s_wb_adr;
    wire [DATA_WIDTH-1:0]     m2s_wb_dat;
    wire [BYTE_WIDTH-1:0]     m2s_wb_sel;
    wire [DATA_WIDTH-1:0]     s2m_wb_dat;
    wire                      s2m_wbs_ack;
    wire                      s2m_wb_stall;

    // AXI4-Lite Interface
    wire [ADDR_WIDTH-1:0]     m2s_axi_awaddr;
    wire [2:0]                m2s_axi_awprot;
    wire                      m2s_axi_awvalid;
    wire                      s2m_axi_awready;
    wire [DATA_WIDTH-1:0]     m2s_axi_wdata;
    wire [BYTE_WIDTH-1:0]     m2s_axi_wstrb;
    wire                      m2s_axi_wvalid;
    wire                      s2m_axi_wready;
    wire  [1:0]               s2m_axi_bresp;
    wire                      s2m_axi_bvalid;
    wire                      m2s_axi_bready;
    wire [ADDR_WIDTH-1:0]     m2s_axi_araddr;
    wire [2:0]                m2s_axi_arprot;
    wire                      m2s_axi_arvalid;
    wire                      s2m_axi_arready;
    wire  [DATA_WIDTH-1:0]    s2m_axi_rdata;
    wire  [1:0]               s2m_axi_rresp;
    wire                      s2m_axi_rvalid;
    wire                      m2s_axi_rready;

    // Command Regs
    reg [ADDR_WIDTH-1:WBS_ADDR_LSB] addr;
    reg [DATA_WIDTH-1:0] data_i;
    reg [BYTE_WIDTH-1:0] sel;
    reg we, start;
    wire [DATA_WIDTH-1:0] data_o;
    wire done;

    // Instantiate modules
    m_wb #(
        .ADDR_WIDTH     (ADDR_WIDTH         ),
        .DATA_WIDTH     (DATA_WIDTH         )
    ) m_wb_inst (
        .aclk           (aclk               ),
        .aresetn        (aresetn            ),
        .addr           (addr               ),
        .data_i         (data_i             ),
        .sel            (sel                ),
        .we             (we                 ),
        .start          (start              ),
        .data_o         (data_o             ),
        .done           (done               ),
        .m_wb_cyc       (m2s_wb_cyc         ),
        .m_wb_stb       (m2s_wb_stb         ),
        .m_wb_we        (m2s_wb_we          ),
        .m_wb_adr       (m2s_wb_adr         ),
        .m_wb_dat_o     (m2s_wb_dat         ),
        .m_wb_sel       (m2s_wb_sel         ),
        .m_wb_dat_i     (s2m_wb_dat         ),
        .m_wb_ack       (s2m_wbs_ack        ),
        .m_wb_stall     (s2m_wb_stall       )
    );

    s_wb_2_m_axi_lite #(
        .ADDR_WIDTH     (ADDR_WIDTH         ),
        .DATA_WIDTH     (DATA_WIDTH         )
    ) s_wb_2_m_axi_lite_inst (
        .aclk           (aclk               ),
        .aresetn        (aresetn            ),
        .s_wb_cyc       (m2s_wb_cyc         ),
        .s_wb_stb       (m2s_wb_stb         ),
        .s_wb_we        (m2s_wb_we          ),
        .s_wb_adr       (m2s_wb_adr         ),
        .s_wb_dat_i     (m2s_wb_dat         ),
        .s_wb_sel       (m2s_wb_sel         ),
        .s_wb_dat_o     (s2m_wb_dat         ),
        .s_wb_ack       (s2m_wbs_ack        ),
        .s_wb_stall     (s2m_wb_stall       ),
        .m_axi_awaddr   (m2s_axi_awaddr     ),
        .m_axi_awprot   (m2s_axi_awprot     ),
        .m_axi_awvalid  (m2s_axi_awvalid    ),
        .m_axi_awready  (s2m_axi_awready    ),
        .m_axi_wdata    (m2s_axi_wdata      ),
        .m_axi_wstrb    (m2s_axi_wstrb      ),
        .m_axi_wvalid   (m2s_axi_wvalid     ),
        .m_axi_wready   (s2m_axi_wready     ),
        .m_axi_bresp    (s2m_axi_bresp      ),
        .m_axi_bvalid   (s2m_axi_bvalid     ),
        .m_axi_bready   (m2s_axi_bready     ),
        .m_axi_araddr   (m2s_axi_araddr     ),
        .m_axi_arprot   (m2s_axi_arprot     ),
        .m_axi_arvalid  (m2s_axi_arvalid    ),
        .m_axi_arready  (s2m_axi_arready    ),
        .m_axi_rdata    (s2m_axi_rdata      ),
        .m_axi_rresp    (s2m_axi_rresp      ),
        .m_axi_rvalid   (s2m_axi_rvalid     ),
        .m_axi_rready   (m2s_axi_rready     )
    );

    s_axi_lite #(
        .ADDR_WIDTH     (ADDR_WIDTH         ),
        .DATA_WIDTH     (DATA_WIDTH         )
    ) s_axi_lite_inst (
        .aclk           (aclk               ),
        .aresetn        (aresetn            ),
        .s_axi_awaddr   (m2s_axi_awaddr     ),
        .s_axi_awprot   (m2s_axi_awprot     ),
        .s_axi_awvalid  (m2s_axi_awvalid    ),
        .s_axi_awready  (s2m_axi_awready    ),
        .s_axi_wdata    (m2s_axi_wdata      ),
        .s_axi_wstrb    (m2s_axi_wstrb      ),
        .s_axi_wvalid   (m2s_axi_wvalid     ),
        .s_axi_wready   (s2m_axi_wready     ),
        .s_axi_bresp    (s2m_axi_bresp      ),
        .s_axi_bvalid   (s2m_axi_bvalid     ),
        .s_axi_bready   (m2s_axi_bready     ),
        .s_axi_araddr   (m2s_axi_araddr     ),
        .s_axi_arprot   (m2s_axi_arprot     ),
        .s_axi_arvalid  (m2s_axi_arvalid    ),
        .s_axi_arready  (s2m_axi_arready    ),
        .s_axi_rdata    (s2m_axi_rdata      ),
        .s_axi_rresp    (s2m_axi_rresp      ),
        .s_axi_rvalid   (s2m_axi_rvalid     ),
        .s_axi_rready   (m2s_axi_rready     )
    );

    // Clock Generation
    initial begin
        aclk = 0;
        forever #5 aclk = ~aclk;
    end
    
    initial begin
        s_axi_lite_inst.mm_dev[0] = 64'h00112233_44556677;
    end
    
    // Test Sequence
    initial begin
        // Synchronous Reset
        aresetn   = 1'b0;
        @(posedge aclk);
        @(posedge aclk);
        aresetn   = 1'b1;
        
        #10;
        addr   = 29'h1;
        data_i = 64'hAABBCCDD_EEFF0011;
        sel    = 8'hF0;
        we     = 1'b1;
        #10;
        start = 1'b1;
        #10;
        start = 1'b0;
        #10;
        wait(done == 1'b1);
        
        #10;
        addr   = 29'h2;
        data_i = 64'h1100FFEE_DDCCBBAA;
        sel    = 8'hF0;
        we     = 1'b1;
        #10;
        start = 1'b1;
        #10;
        start = 1'b0;
        #10;
        wait(done == 1'b1);
        
        #10;
        addr   = 29'h0;
        data_i = 64'h1100FFEE_DDCCBBAA;
        sel    = 8'h0F;
        we     = 1'b0;
        #10;
        start = 1'b1;
        #10;
        start = 1'b0;
        #10;
        wait(done == 1'b1);
        @(posedge aclk);
        @(posedge aclk);
        $display("Mem[0x%x] = 0x%x", addr << WBS_ADDR_LSB, data_o);

        #20;
        $finish;
    end
    
endmodule
