/*
 * Testbench for tb
 *
 * Description:
 *   This testbench verifies the wbs2axilitem bridge module. It includes:
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

module tb_2;

    // Parameters
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 64;
    localparam BYTE_WIDTH = DATA_WIDTH / 8;
    
    localparam S_AXI_DATA_WIDTH = 32;
    localparam S_AXI_BYTE_WIDTH = S_AXI_DATA_WIDTH / 8;
    
    localparam DEV_SIZE   = 1024;

    // Clock and Reset
    reg                         aclk;
    reg                         aresetn;
    
    // S_AXI (PS -> Microwatt control slave)
    reg                         s_axi_awvalid = 0;
    wire                        s_axi_awready;
    reg  [ADDR_WIDTH-1:0]       s_axi_awaddr  = 32'd0;
    reg  [2:0]                  s_axi_awprot  = 3'd0;
    reg                         s_axi_wvalid  = 0;
    wire                        s_axi_wready;
    reg  [S_AXI_DATA_WIDTH-1:0] s_axi_wdata   = 32'b0;
    reg  [S_AXI_BYTE_WIDTH-1:0] s_axi_wstrb   = 4'hF;
    wire                        s_axi_bvalid;
    reg                         s_axi_bready  = 0;
    wire [1:0]                  s_axi_bresp;
    reg                         s_axi_arvalid = 0;
    wire                        s_axi_arready;
    reg  [ADDR_WIDTH-1:0]       s_axi_araddr  = 32'd0;
    reg  [2:0]                  s_axi_arprot  = 3'd0;
    wire                        s_axi_rvalid;
    reg                         s_axi_rready  = 0;
    wire [S_AXI_DATA_WIDTH-1:0] s_axi_rdata;
    wire [1:0]                  s_axi_rresp;

    // AXI4-Lite Master Interface
    wire [ADDR_WIDTH-1:0]       m2s_axi_awaddr;
    wire [2:0]                  m2s_axi_awprot;
    wire                        m2s_axi_awvalid;
    wire                        s2m_axi_awready;
    wire [DATA_WIDTH-1:0]       m2s_axi_wdata;
    wire [BYTE_WIDTH-1:0]       m2s_axi_wstrb;
    wire                        m2s_axi_wvalid;
    wire                        s2m_axi_wready;
    wire  [1:0]                 s2m_axi_bresp;
    wire                        s2m_axi_bvalid;
    wire                        m2s_axi_bready;
    wire [ADDR_WIDTH-1:0]       m2s_axi_araddr;
    wire [2:0]                  m2s_axi_arprot;
    wire                        m2s_axi_arvalid;
    wire                        s2m_axi_arready;
    wire  [DATA_WIDTH-1:0]      s2m_axi_rdata;
    wire  [1:0]                 s2m_axi_rresp;
    wire                        s2m_axi_rvalid;
    wire                        m2s_axi_rready;

    // Instantiate modules
    microwatt_wrapper #(
        .ADDR_WIDTH     (ADDR_WIDTH         ),
        .DATA_WIDTH     (DATA_WIDTH         )
    ) microwatt_wrapper_inst (
        .aclk           (aclk               ),
        .aresetn        (aresetn            ),
        
        .ext_irq_uart0  (                   ),
        .ext_irq_eth    (                   ),
        .ext_irq_sdcard (                   ),
        
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
        .s_axi_rready   (s_axi_rready       ),
        
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

    s_axi_lite_sim #(
        .ADDR_WIDTH     (ADDR_WIDTH         ),
        .DATA_WIDTH     (DATA_WIDTH         ),
        
        .DEV_SIZE       (DEV_SIZE           )
    ) s_axi_lite_sim_inst (
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
      
    // ---------- Helper tasks to write control regs via S_AXI ----------
    task automatic write_slave_reg(input [ADDR_WIDTH-1:0] reg_addr, input [S_AXI_DATA_WIDTH-1:0] value);
        begin
            // Issue AW + W (simple two-cycle handshake)
            @(posedge aclk);
            s_axi_awaddr  <= reg_addr;
            s_axi_awvalid <= 1;
            s_axi_wdata   <= value;
            s_axi_wstrb   <= 4'hF;
            s_axi_wvalid  <= 1;
            // wait for ready signals
            wait (s_axi_awready == 1);
            wait (s_axi_wready  == 1);
            @(posedge aclk);
            s_axi_awvalid <= 0;
            s_axi_wvalid  <= 0;
            // wait for BVALID, then ack
            wait (s_axi_bvalid == 1);
            @(posedge aclk);
            s_axi_bready <= 1;
            @(posedge aclk);
            s_axi_bready <= 0;
        end
    endtask
    
    // ---------- Helper tasks to read control regs via S_AXI ----------
    task read_slave_reg(input [ADDR_WIDTH-1:0] reg_addr, output [S_AXI_DATA_WIDTH-1:0] value);
        begin
            // Issue AR (simple two-cycle handshake)
            s_axi_arvalid <= 1;
            s_axi_araddr  <= reg_addr;
            wait (s_axi_arready == 1);
            @(posedge aclk);
            s_axi_arvalid <= 0;
            s_axi_rready  <= 1;
            wait (s_axi_rvalid == 1);
            value <= s_axi_rdata;
            @(posedge aclk);
            s_axi_rready  <= 0;
        end
    endtask

    // Clock Generation
    initial begin
        aclk = 0;
        forever #5 aclk = ~aclk;
    end
    
    // Test Sequence
    reg [S_AXI_DATA_WIDTH-1:0] out;
    initial begin
        // Synchronous Reset
        aresetn   = 1'b0;
        @(posedge aclk);
        @(posedge aclk);
        aresetn   = 1'b1;
        
        // Ask Controller to Activate Microwatt
        @(posedge aclk);
        @(posedge aclk);
        write_slave_reg(32'hA000_0004, 32'h2000_0000);
        write_slave_reg(32'hA000_0000, 32'h0000_0001);
        
        #10000;
        $finish;
    end
      
endmodule