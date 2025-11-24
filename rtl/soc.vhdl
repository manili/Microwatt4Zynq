library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.common.all;
use work.wishbone_types.all;

entity soc is
    generic (
        -- Core Configuration
        NCPUS              : positive := 1;
        HAS_FPU            : boolean  := true;
        HAS_BTC            : boolean  := true;

        -- Toolchain and Debug Configuration
        SIM                : boolean := false;
        DISABLE_FLATTEN_CORE : boolean := false;
        LOG_LENGTH         : natural := 0;
        ALT_RESET_ADDRESS  : std_logic_vector(63 downto 0) := (others => '0')
    );
    port (
        rst            : in  std_ulogic;
        system_clk     : in  std_ulogic;
        wb_master_out  : out wishbone_master_out;
        wb_master_in   : in  wishbone_slave_out := wishbone_slave_out_init;
        run_out        : out std_ulogic;
        run_outs       : out std_ulogic_vector(NCPUS-1 downto 0);
        
        ext_irq_uart0  : in  std_ulogic;
        ext_irq_eth    : in  std_ulogic;
        ext_irq_sdcard : in  std_ulogic
    );
end entity soc;

architecture behaviour of soc is
    -- Internal signal declarations
    signal rst_wbar    : std_ulogic;
    signal rst_xics    : std_ulogic;
    signal rst_core    : std_ulogic_vector(NCPUS-1 downto 0);
    signal alt_reset_d : std_ulogic;
    signal tb_ctrl     : timebase_ctrl;

    -- Wishbone signals for the arbiter
    constant NUM_WB_MASTERS : positive := NCPUS * 2;
    signal wb_masters_out : wishbone_master_out_vector(0 to NUM_WB_MASTERS-1);
    signal wb_masters_in  : wishbone_slave_out_vector(0 to NUM_WB_MASTERS-1);
    signal wb_master_out_from_arb : wishbone_master_out;
    signal wb_master_in_to_arb    : wishbone_slave_out;
    
    -- Wishbone master (output of arbiter):
    signal wb_snoop           : wishbone_master_out;

    -- Main "IO" bus, from main slave decoder to the latch
    signal wb_io_in     : wishbone_master_out;
    signal wb_io_out    : wishbone_slave_out;

    -- Secondary (smaller) IO bus after the IO bus latch
    signal wb_sio_out    : wb_io_master_out;
    signal wb_sio_in     : wb_io_slave_out;
    
    -- XICS signals:
    signal wb_xics_icp_in   : wb_io_master_out;
    signal wb_xics_icp_out  : wb_io_slave_out;
    signal wb_xics_ics_in   : wb_io_master_out;
    signal wb_xics_ics_out  : wb_io_slave_out;
    signal int_level_in     : std_ulogic_vector(15 downto 0);
    signal ics_to_icp       : ics_to_icp_t;
    signal core_ext_irq     : std_ulogic_vector(NCPUS-1 downto 0) := (others => '0');
    
    -- IO branch split:
    type slave_io_type is (SLAVE_IO_ICP,
                           SLAVE_IO_ICS);
    signal current_io_decode : slave_io_type;

    signal io_cycle_none      : std_ulogic;
    signal io_cycle_icp       : std_ulogic;
    signal io_cycle_ics       : std_ulogic;

    -- CPU core status
    signal core_run_out : std_ulogic_vector(NCPUS-1 downto 0);

    -- Inter-core messaging
    type msg_percpu_array is array(0 to NCPUS-1) of std_ulogic_vector(NCPUS-1 downto 0);
    signal msgs : msg_percpu_array;

begin

    -- Instantiate Processor Core(s)
    processors: for i in 0 to NCPUS-1 generate
        signal msgin : std_ulogic;
    begin
        core: entity work.core
            generic map (
                SIM               => SIM,
                CPU_INDEX         => i,
                NCPUS             => NCPUS,
                HAS_FPU           => HAS_FPU,
                HAS_BTC           => HAS_BTC,
                DISABLE_FLATTEN   => DISABLE_FLATTEN_CORE,
                ALT_RESET_ADDRESS => ALT_RESET_ADDRESS,
                LOG_LENGTH        => LOG_LENGTH
            )
            port map (
                clk               => system_clk,
                rst               => rst_core(i),
                alt_reset         => alt_reset_d,
                run_out           => core_run_out(i),
                tb_ctrl           => tb_ctrl,
                wishbone_insn_in  => wb_masters_in(i + NCPUS),
                wishbone_insn_out => wb_masters_out(i + NCPUS),
                wishbone_data_in  => wb_masters_in(i),
                wishbone_data_out => wb_masters_out(i),
                wb_snoop_in       => wb_snoop,
                ext_irq           => core_ext_irq(i),
                dmi_addr          => "0000",
                dmi_din           => (others => '0'),
                dmi_dout          => open,
                dmi_wr            => '0',
                dmi_ack           => open,
                dmi_req           => '0',
                msg_out           => msgs(i),
                msg_in            => msgin
            );

        process(all)
            variable m : std_ulogic;
        begin
            m := '0';
            for j in 0 to NCPUS-1 loop
                if j /= i then
                    m := m or msgs(j)(i);
                end if;
            end loop;
            msgin <= m;
        end process;
    end generate;

    run_out  <= or(core_run_out);
    run_outs <= core_run_out;
    
    -- Instantiate Arbiter
    wishbone_arbiter_0: entity work.wishbone_arbiter
        generic map (
            NUM_MASTERS => NUM_WB_MASTERS
        )
        port map (
            clk            => system_clk,
            rst            => rst_wbar,
            wb_masters_in  => wb_masters_out,
            wb_masters_out => wb_masters_in,
            wb_slave_out   => wb_master_out_from_arb,
            wb_slave_in    => wb_master_in_to_arb
        );
    
    -- Snoop bus going to caches.
    -- Gate stb with stall so the caches don't see the stalled strobes.
    -- That way if the caches see a strobe when their wishbone is stalled,
    -- they know it is an access by another master.
    process(all)
    begin
        wb_snoop <= wb_master_out_from_arb;
        if wb_master_in_to_arb.stall = '1' then
            wb_snoop.stb <= '0';
        end if;
    end process;
        
    -- Tie off unused control signals and manage resets
    tb_ctrl.reset   <= rst;
    tb_ctrl.rd_prot <= '0';
    tb_ctrl.freeze  <= '0';
    alt_reset_d     <= '1';  -- Fixed to '1'; uses ALT_RESET_ADDRESS always (no syscon toggle)

    resets: process(system_clk)
    begin
        if rising_edge(system_clk) then
            for i in 0 to NCPUS-1 loop
                rst_core(i) <= rst;
            end loop;
            rst_wbar    <= rst;
            rst_xics    <= rst;
        end if;
    end process;
    
    -- Main Address Decoder with Remapping Logic
    main_decoder: process(all)
        variable match   : std_ulogic_vector(31 downto 12);
        variable is_io   : std_ulogic;
    begin
        match := wb_master_out_from_arb.adr(28 downto 9);
        is_io := '1' when (std_match(match, x"C0004") or std_match(match, x"C0005")) else '0';
        wb_io_in <= wb_master_out_from_arb;
        wb_io_in.cyc <= wb_master_out_from_arb.cyc and is_io;
        wb_io_in.stb <= wb_master_out_from_arb.stb and is_io;
        wb_master_out <= wb_master_out_from_arb;
        wb_master_out.cyc <= wb_master_out_from_arb.cyc and not is_io;
        wb_master_out.stb <= wb_master_out_from_arb.stb and not is_io;
        wb_master_in_to_arb <= wb_io_out when is_io = '1' else wb_master_in;
    end process;
    
    xics_icp: entity work.xics_icp
        generic map(
            NCPUS => NCPUS
        )
        port map(
            clk => system_clk,
            rst => rst_xics,
            wb_in => wb_xics_icp_in,
            wb_out => wb_xics_icp_out,
            ics_in => ics_to_icp,
            core_irq_out => core_ext_irq
	    );

    xics_ics: entity work.xics_ics
        generic map(
            NCPUS     => NCPUS,
            SRC_NUM   => 16,
            PRIO_BITS => 3
        )
        port map(
            clk => system_clk,
            rst => rst_xics,
            wb_in => wb_xics_ics_in,
            wb_out => wb_xics_ics_out,
            int_level_in => int_level_in,
            icp_out => ics_to_icp
	    );
	    
    -- Assign external interrupts
    interrupts: process(all)
    begin
        int_level_in <= (others => '0');
        int_level_in(0) <= ext_irq_uart0;
        int_level_in(1) <= ext_irq_eth;
        int_level_in(2) <= '0'; -- uart1_irq;
        int_level_in(3) <= ext_irq_sdcard;
        int_level_in(4) <= '0'; -- gpio_intr;
    end process;

    -- IO wishbone slave 64->32 bits converter
    --
    -- For timing reasons, this adds a one cycle latch on the way both
    -- in and out. This relaxes timing and routing pressure on the "main"
    -- memory bus by moving all simple IOs to a slower 32-bit bus.
    --
    -- This implementation is rather dumb at the moment, no stash buffer,
    -- so we stall whenever that latch is busy. This can be improved.
    --
    slave_io_latch: process(system_clk)
        -- State
        type state_t is (IDLE, WAIT_ACK_BOT, WAIT_ACK_TOP);
        variable state : state_t;

        -- Misc
        variable has_top : boolean;
        variable has_bot : boolean;
        variable do_cyc  : std_ulogic;
        variable end_cyc : std_ulogic;
        variable slave_io : slave_io_type;
        variable match   : std_ulogic_vector(31 downto 12);
        variable dat_latch : std_ulogic_vector(31 downto 0);
        variable sel_latch : std_ulogic_vector(3 downto 0);
    begin
        if rising_edge(system_clk) then
            do_cyc := '0';
            end_cyc := '0';
            if (rst) then
                state := IDLE;
                wb_io_out.ack <= '0';
                wb_io_out.stall <= '0';
                wb_io_out.dat <= (others => '0');  -- Default to 0 on reset
                wb_sio_out.stb <= '0';
                wb_sio_out.cyc <= '0';  -- Ensure cyc is cleared on reset
                end_cyc := '1';
                has_top := false;
                has_bot := false;
                dat_latch := (others => '0');
                sel_latch := (others => '0');
            else
                case state is
                when IDLE =>
                    -- Clear ACK in case it was set
                    wb_io_out.ack <= '0';

                    -- Do we have a cycle ?
                    if wb_io_in.cyc = '1' and wb_io_in.stb = '1' then
                        -- Stall master until we are done, we are't (yet) pipelining
                        -- this, it's all slow IOs. Note: The current cycle has
                        -- already been accepted as "stall" was 0, this only blocks
                        -- the next one. This means that we must latch
                        -- everything we need from wb_io_in in *this* cycle.
                        --
                        wb_io_out.stall <= '1';

                        -- Start cycle downstream
                        do_cyc := '1';
                        wb_sio_out.stb <= '1';

                        -- Copy write enable to IO out, copy address as well
                        wb_sio_out.we <= wb_io_in.we;
                        wb_sio_out.adr <= wb_io_in.adr(wb_sio_out.adr'left - 1 downto 0) & '0';

                        -- Do we have a top word and/or a bottom word ?
                        has_top := wb_io_in.sel(7 downto 4) /= "0000";
                        has_bot := wb_io_in.sel(3 downto 0) /= "0000";

                        -- Remember the top word as it might be needed later
                        dat_latch := wb_io_in.dat(63 downto 32);
                        sel_latch := wb_io_in.sel(7 downto 4);

                        -- If we have a bottom word, handle it first, otherwise
                        -- send the top word down.
                        if has_bot then
                            -- Always update out.dat, it doesn't matter if we
                            -- update it on reads and it saves  mux
                            wb_sio_out.dat <= wb_io_in.dat(31 downto 0);
                            wb_sio_out.sel <= wb_io_in.sel(3 downto 0);

                            -- Wait for ack
                            state := WAIT_ACK_BOT;
                        else
                            wb_sio_out.dat <= wb_io_in.dat(63 downto 32);
                            wb_sio_out.sel <= wb_io_in.sel(7 downto 4);

                            -- Bump address
                            wb_sio_out.adr(0) <= '1';

                            -- Wait for ack
                            state := WAIT_ACK_TOP;
                        end if;
                    end if;
                when WAIT_ACK_BOT =>
                    -- If we aren't stalled by the device, clear stb
                    if wb_sio_in.stall = '0' then
                        wb_sio_out.stb <= '0';
                    end if;

                    -- Handle ack
                    if wb_sio_in.ack = '1' then
                         -- Always latch the data, it doesn't matter if it was
                         -- a write and it saves a mux
                        wb_io_out.dat(31 downto 0) <= wb_sio_in.dat;

                        -- Do we have a "top" part as well ?
                        if has_top then
                            wb_sio_out.dat <= dat_latch;
                            wb_sio_out.sel <= sel_latch;

                            -- Bump address and set STB
                            wb_sio_out.adr(0) <= '1';
                            wb_sio_out.stb <= '1';

                            -- Wait for new ack
                            state := WAIT_ACK_TOP;
                        else
                            -- We are done, ack up, clear cyc downstream
                            end_cyc := '1';

                            -- And ack & unstall upstream
                            wb_io_out.ack <= '1';
                            wb_io_out.stall <= '0';

                            -- Wait for next one
                            state := IDLE;
                        end if;
                    end if;
                when WAIT_ACK_TOP =>
                    -- If we aren't stalled by the device, clear stb
                    if wb_sio_in.stall = '0' then
                        wb_sio_out.stb <= '0';
                    end if;

                    -- Handle ack
                    if wb_sio_in.ack = '1' then
                         -- Always latch the data, it doesn't matter if it was
                         -- a write and it saves a mux
                        wb_io_out.dat(63 downto 32) <= wb_sio_in.dat;

                        -- We are done, ack up, clear cyc downstram
                        end_cyc := '1';

                        -- And ack & unstall upstream
                        wb_io_out.ack <= '1';
                        wb_io_out.stall <= '0';

                        -- Wait for next one
                        state := IDLE;
                    end if;
                end case;
            end if;

            -- Create individual registered cycle signals for the wishbones
            -- going to the various peripherals
            --
            -- Note: This needs to happen on the cycle matching state = IDLE,
            -- as wb_io_in content can only be relied upon on that one cycle.
            -- This works here because do_cyc is a variable, not a signal, and
            -- thus here we observe the value set above in the state machine
            -- on the same cycle rather than the next one.
            --
            if do_cyc = '1' or end_cyc = '1' then
                io_cycle_none      <= '0';
                io_cycle_icp       <= '0';
                io_cycle_ics       <= '0';
                wb_sio_out.cyc     <= '0';  -- Clear cyc on end_cyc or prep for set
            end if;
            if do_cyc = '1' then
                -- Decode I/O address
                -- This is real address bits 29 downto 12
                match := wb_io_in.adr(28 downto 9);
                slave_io := SLAVE_IO_ICP;
                if std_match(match, x"C0004") then
                    slave_io := SLAVE_IO_ICP;
                    io_cycle_icp <= '1';
                elsif std_match(match, x"C0005") then
                    slave_io := SLAVE_IO_ICS;
                    io_cycle_ics <= '1';
                else
                    io_cycle_none <= '1';
                end if;
                current_io_decode <= slave_io;
                wb_sio_out.cyc <= '1';
            end if;
        end if;
    end process;

    -- IO wishbone slave interconnect.
    --
    slave_io_intercon: process(all)
    begin
        -- Only give xics 8 bits of wb addr (for now...)
        wb_xics_icp_in <= wb_sio_out;
        wb_xics_icp_in.adr <= (others => '0');
        wb_xics_icp_in.adr(5 downto 0) <= wb_sio_out.adr(5 downto 0);
        wb_xics_icp_in.cyc  <= io_cycle_icp;
        wb_xics_ics_in <= wb_sio_out;
        wb_xics_ics_in.adr <= (others => '0');
        wb_xics_ics_in.adr(9 downto 0) <= wb_sio_out.adr(9 downto 0);
        wb_xics_ics_in.cyc  <= io_cycle_ics;
	
        case current_io_decode is
        when SLAVE_IO_ICP =>
            wb_sio_in <= wb_xics_icp_out;
        when SLAVE_IO_ICS =>
            wb_sio_in <= wb_xics_ics_out;
        end case;

        -- Default response, ack & return all 1's
        if io_cycle_none = '1' then
            wb_sio_in.dat <= (others => '1');
            wb_sio_in.ack <= wb_sio_out.stb and wb_sio_out.cyc;
            wb_sio_in.stall <= '0';
        end if;

    end process;

end architecture behaviour;
