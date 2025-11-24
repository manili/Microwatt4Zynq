--
-- Microwatt SoC Top-Level Wrapper for Zynq UltraScale+ Integration
--
--
-- Architecture Overview:
-- 1. Instantiates a modified, stripped-down Microwatt SoC (`soc.vhdl`) which
--    contains only the CPU core(s) and a XICS. This SoC has no internal
--    peripherals and presents a single Wishbone master port for all external access.
-- 2. Instantiates a Wishbone-to-AXI4-Lite bridge (`s_wb_2_m_axi_lite.v`).
-- 3. Connects the Microwatt SoC's Wishbone master port to the bridge's Wishbone slave port.
-- 4. Exposes the bridge's AXI4-Lite master port as the primary interface of this IP.
-- 5. Exposes interrupt inputs (`ext_irq_*`) which are wired directly to
--    the Microwatt core's external interrupt pins.
--
-- This design allows the Microwatt core to act as a master on the Zynq's AXI fabric,
-- accessing the PS-controlled DDR4 memory and peripherals.
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_types.all;
use work.utils.all;

entity microwatt_zynq_top is
    generic (
        NCPUS             : positive := 1;
        HAS_FPU           : boolean  := true;
        HAS_BTC           : boolean  := true;
        LOG_LENGTH        : natural  := 0;
        ALT_RESET_ADDRESS : std_logic_vector(63 downto 0) := (others => '0');
        
        ADDR_WIDTH        : integer  := 32;
        DATA_WIDTH        : integer  := 64;
        BYTE_WIDTH        : integer  := DATA_WIDTH / 8;
        LOG_BYTE_W        : integer  := 3;
        WBS_ADDR_LSB      : integer  := 3
    );
    port (
        aclk              : in  std_ulogic;
        aresetn           : in  std_ulogic;

        ext_irq_uart0     : in  std_ulogic;
        ext_irq_eth       : in  std_ulogic;
        ext_irq_sdcard    : in  std_ulogic;
        
        m_axi_awprot      : out std_ulogic_vector(2 downto 0);
        m_axi_awvalid     : out std_ulogic;
        m_axi_awaddr      : out std_ulogic_vector(ADDR_WIDTH-1 downto 0);
        m_axi_awready     : in  std_ulogic;
        m_axi_wvalid      : out std_ulogic;
        m_axi_wdata       : out std_ulogic_vector(DATA_WIDTH-1 downto 0);
        m_axi_wstrb       : out std_ulogic_vector(BYTE_WIDTH-1 downto 0);
        m_axi_wready      : in  std_ulogic;
        m_axi_bvalid      : in  std_ulogic;
        m_axi_bresp       : in  std_ulogic_vector(1 downto 0);
        m_axi_bready      : out std_ulogic;
        m_axi_arprot      : out std_ulogic_vector(2 downto 0);
        m_axi_arvalid     : out std_ulogic;
        m_axi_araddr      : out std_ulogic_vector(ADDR_WIDTH-1 downto 0);
        m_axi_arready     : in  std_ulogic;
        m_axi_rvalid      : in  std_ulogic;
        m_axi_rdata       : in  std_ulogic_vector(DATA_WIDTH-1 downto 0);
        m_axi_rresp       : in  std_ulogic_vector(1 downto 0);
        m_axi_rready      : out std_ulogic
    );
end entity microwatt_zynq_top;

architecture rtl of microwatt_zynq_top is
    signal rst_s           : std_ulogic;
    signal wb_master_o     : wishbone_master_out;
    signal wb_master_i     : wishbone_slave_out;
    signal core_run_out    : std_ulogic;
    signal core_run_outs   : std_ulogic_vector(NCPUS-1 downto 0);
    
    signal bridge_awaddr_internal   : std_ulogic_vector(31 downto 0);
    signal bridge_araddr_internal   : std_ulogic_vector(31 downto 0);
    
    component soc is
        generic (
            NCPUS              : positive;
            HAS_FPU            : boolean;
            HAS_BTC            : boolean;
            SIM                : boolean;
            DISABLE_FLATTEN_CORE : boolean;
            LOG_LENGTH         : natural;
            ALT_RESET_ADDRESS  : std_logic_vector(63 downto 0)
        );
        port (
            rst            : in  std_ulogic;
            system_clk     : in  std_ulogic;
            wb_master_out  : out wishbone_master_out;
            wb_master_in   : in  wishbone_slave_out;
            run_out        : out std_ulogic;
            run_outs       : out std_ulogic_vector(NCPUS-1 downto 0);
            
            ext_irq_uart0  : in  std_ulogic;
            ext_irq_eth    : in  std_ulogic;
            ext_irq_sdcard : in  std_ulogic
        );
    end component soc;
    
    component s_wb_2_m_axi_lite is
        generic (
            ADDR_WIDTH   : integer := ADDR_WIDTH;
            DATA_WIDTH   : integer := DATA_WIDTH;
            BYTE_WIDTH   : integer := BYTE_WIDTH;
            LOG_BYTE_W   : integer := LOG_BYTE_W;
            WBS_ADDR_LSB : integer := WBS_ADDR_LSB
        );
        port (
            aclk          : in  std_ulogic;
            aresetn       : in  std_ulogic;
            s_wb_cyc      : in  std_ulogic;
            s_wb_stb      : in  std_ulogic;
            s_wb_we       : in  std_ulogic;
            s_wb_adr      : in  std_ulogic_vector(ADDR_WIDTH-1 downto WBS_ADDR_LSB);
            s_wb_dat_i    : in  std_ulogic_vector(DATA_WIDTH-1 downto 0);
            s_wb_sel      : in  std_ulogic_vector(BYTE_WIDTH-1 downto 0);
            s_wb_dat_o    : out std_ulogic_vector(DATA_WIDTH-1 downto 0);
            s_wb_ack      : out std_ulogic;
            s_wb_stall    : out std_ulogic;
            m_axi_awprot  : out std_ulogic_vector(2 downto 0);
            m_axi_awvalid : out std_ulogic;
            m_axi_awaddr  : out std_ulogic_vector(ADDR_WIDTH-1 downto 0);
            m_axi_awready : in  std_ulogic;
            m_axi_wvalid  : out std_ulogic;
            m_axi_wdata   : out std_ulogic_vector(DATA_WIDTH-1 downto 0);
            m_axi_wstrb   : out std_ulogic_vector(BYTE_WIDTH-1 downto 0);
            m_axi_wready  : in  std_ulogic;
            m_axi_bvalid  : in  std_ulogic;
            m_axi_bresp   : in  std_ulogic_vector(1 downto 0);
            m_axi_bready  : out std_ulogic;
            m_axi_arprot  : out std_ulogic_vector(2 downto 0);
            m_axi_arvalid : out std_ulogic;
            m_axi_araddr  : out std_ulogic_vector(ADDR_WIDTH-1 downto 0);
            m_axi_arready : in  std_ulogic;
            m_axi_rvalid  : in  std_ulogic;
            m_axi_rdata   : in  std_ulogic_vector(DATA_WIDTH-1 downto 0);
            m_axi_rresp   : in  std_ulogic_vector(1 downto 0);
            m_axi_rready  : out std_ulogic
        );
    end component s_wb_2_m_axi_lite;

begin
    rst_s <= not aresetn;

    microwatt_soc_inst: soc
        generic map (
            NCPUS              => NCPUS,
            HAS_FPU            => HAS_FPU,
            HAS_BTC            => HAS_BTC,
            SIM                => false,
            DISABLE_FLATTEN_CORE => false,
            LOG_LENGTH         => LOG_LENGTH,
            ALT_RESET_ADDRESS  => ALT_RESET_ADDRESS
        )
        port map (
            rst            => rst_s,
            system_clk     => aclk,
            wb_master_out  => wb_master_o,
            wb_master_in   => wb_master_i,
            run_out        => core_run_out,
            run_outs       => core_run_outs,
            
            ext_irq_uart0  => ext_irq_uart0,
            ext_irq_eth    => ext_irq_eth,
            ext_irq_sdcard => ext_irq_sdcard
        );

    s_wb_2_m_axi_lite_inst: s_wb_2_m_axi_lite
        generic map (
            ADDR_WIDTH   => ADDR_WIDTH,
            DATA_WIDTH   => DATA_WIDTH,
            BYTE_WIDTH   => BYTE_WIDTH,
            WBS_ADDR_LSB => WBS_ADDR_LSB
        )
        port map (
            aclk          => aclk,
            aresetn       => aresetn,
            s_wb_cyc      => wb_master_o.cyc,
            s_wb_stb      => wb_master_o.stb,
            s_wb_we       => wb_master_o.we,
            s_wb_adr      => wb_master_o.adr,
            s_wb_dat_i    => wb_master_o.dat,
            s_wb_sel      => wb_master_o.sel,
            s_wb_dat_o    => wb_master_i.dat,
            s_wb_ack      => wb_master_i.ack,
            s_wb_stall    => wb_master_i.stall,
            
            m_axi_awaddr  => m_axi_awaddr,
            m_axi_araddr  => m_axi_araddr,
            m_axi_awprot  => m_axi_awprot,
            m_axi_awvalid => m_axi_awvalid,
            m_axi_awready => m_axi_awready,
            m_axi_wdata   => m_axi_wdata,
            m_axi_wstrb   => m_axi_wstrb,
            m_axi_wvalid  => m_axi_wvalid,
            m_axi_wready  => m_axi_wready,
            m_axi_bresp   => m_axi_bresp,
            m_axi_bvalid  => m_axi_bvalid,
            m_axi_bready  => m_axi_bready,
            m_axi_arprot  => m_axi_arprot,
            m_axi_arvalid => m_axi_arvalid,
            m_axi_arready => m_axi_arready,
            m_axi_rdata   => m_axi_rdata,
            m_axi_rresp   => m_axi_rresp,
            m_axi_rvalid  => m_axi_rvalid,
            m_axi_rready  => m_axi_rready
        );

end architecture rtl;
