library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.riscv32_pkg.all;

entity riscv32_csr_machine_trap_setup_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_csr_machine_trap_setup_tb is
        constant clk_period : time := 20 ns;
        signal clk : std_logic := '0';
        signal rst : boolean := false;

        signal mst2slv : riscv32_csr_mst2slv_type;
        signal slv2mst : riscv32_csr_slv2mst_type;

        signal interrupts_enabled : boolean;
        signal interrupt_trigger : boolean := false;

        signal m_timer_interrupt_enabled : boolean;
        signal m_external_interrupt_enabled : boolean;
begin
    clk <= not clk after (clk_period/2);
    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Read from address 2 results in error") then
                mst2slv.address <= 16#2#;
                mst2slv.do_read <= true;
                wait for 1 ns;
                check_true(slv2mst.has_error);
            elsif run("Read from address 0 does not result in error") then
                mst2slv.address <= 16#0#;
                mst2slv.do_read <= true;
                wait for 1 ns;
                check_false(slv2mst.has_error);
            elsif run("Writing 1 to mstatus.MIE enables interrupts") then
                mst2slv.address <= 16#0#;
                mst2slv.do_read <= true;
                mst2slv.do_write <= true;
                mst2slv.write_data <= x"00000008";
                wait for clk_period;
                check_true(interrupts_enabled);
            elsif run("Interrupts are default disabled") then
                check_false(interrupts_enabled);
            elsif run("Writing 1 to mstatus.MIE in wrong register does not enable interrupts") then
                mst2slv.address <= 16#2#;
                mst2slv.do_read <= true;
                mst2slv.do_write <= true;
                mst2slv.write_data <= x"00000008";
                wait for clk_period;
                check_false(interrupts_enabled);
            elsif run("On do_write is false, write is ignored") then
                mst2slv.address <= 16#2#;
                mst2slv.do_read <= true;
                mst2slv.do_write <= false;
                mst2slv.write_data <= x"00000008";
                wait for clk_period;
                check_false(interrupts_enabled);
            elsif run("Write 1 to mstatus.MIE then read mstatus.MIE results in 1") then
                mst2slv.address <= 16#0#;
                mst2slv.do_read <= true;
                mst2slv.do_write <= true;
                mst2slv.write_data <= x"00000008";
                wait for clk_period;
                check_equal(slv2mst.read_data, std_logic_vector'(x"00000008"));
            elsif run("mstatus readonly fields remain at zero") then
                mst2slv.address <= 16#0#;
                mst2slv.do_read <= true;
                mst2slv.do_write <= true;
                mst2slv.write_data <= (others => '1');
                wait for clk_period;
                check_equal(slv2mst.read_data, std_logic_vector'(x"000019aa"));
            elsif run("Check interrupt_trigger response") then
                mst2slv.address <= 16#0#;
                mst2slv.do_read <= true;
                mst2slv.do_write <= true;
                mst2slv.write_data <= x"00000008";
                wait for clk_period;
                mst2slv.do_write <= false;
                interrupt_trigger <= true;
                wait for clk_period;
                interrupt_trigger <= false;
                -- Interrupts should be disabled
                check_false(interrupts_enabled);
                check_equal(slv2mst.read_data(3), '0');
                -- mstatus.MPP should be equal to machine mode
                check_equal(slv2mst.read_data(12 downto 11), riscv32_privilege_level_machine);
                -- mstatus.MPIE should be set to 1, since mstatus.MIE was one
                check_equal(slv2mst.read_data(7), '1');
            elsif run("mstatus.MPIE is 0 if mstatus.MIE was 0 before interrupt") then
                mst2slv.address <= 16#0#;
                mst2slv.do_read <= true;
                mst2slv.do_write <= true;
                mst2slv.write_data <= x"00000000";
                wait for clk_period;
                mst2slv.do_write <= false;
                interrupt_trigger <= true;
                wait for clk_period;
                interrupt_trigger <= false;
                -- Interrupts should be disabled
                check_false(interrupts_enabled);
                check_equal(slv2mst.read_data(3), '0');
                -- mstatus.MPP should be equal to machine mode
                check_equal(slv2mst.read_data(12 downto 11), riscv32_privilege_level_machine);
                -- mstatus.MPIE should be set to 0, since mstatus.MIE was zero
                check_equal(slv2mst.read_data(7), '0');
            elsif run("reset resets mstatus") then
                mst2slv.address <= 16#0#;
                mst2slv.do_read <= true;
                mst2slv.do_write <= true;
                mst2slv.write_data <= (others => '1');
                wait for clk_period;
                mst2slv.do_write <= false;
                rst <= true;
                wait for clk_period;
                rst <= false;
                check_equal(slv2mst.read_data, std_logic_vector'(x"00000000"));
            elsif run("Reading from misa does not result in error") then
                mst2slv.address <= 16#1#;
                mst2slv.do_read <= true;
                wait for clk_period;
                check_false(slv2mst.has_error);
            elsif run("misa.MXL is set to 1") then
                mst2slv.address <= 16#1#;
                mst2slv.do_read <= true;
                wait for clk_period;
                check_equal(slv2mst.read_data(slv2mst.read_data'high downto slv2mst.read_data'high -1), std_logic_vector'("01"));
            elsif run("misa only indicates I extension support") then
                mst2slv.address <= 16#1#;
                mst2slv.do_read <= true;
                wait for clk_period;
                check_equal(slv2mst.read_data(25 downto 9), std_logic_vector'("00000000000000000"));
                check_equal(slv2mst.read_data(8), '1');
                check_equal(slv2mst.read_data(7 downto 0), std_logic_vector'("00000000"));
            elsif run("Writing to misa has no effects") then
                mst2slv.address <= 16#1#;
                mst2slv.do_read <= true;
                mst2slv.do_write <= true;
                mst2slv.write_data <= (others => '1');
                wait for clk_period;
                mst2slv.do_write <= false;
                wait for clk_period;
                check_equal(slv2mst.read_data(25 downto 9), std_logic_vector'("00000000000000000"));
                check_equal(slv2mst.read_data(8), '1');
                check_equal(slv2mst.read_data(7 downto 0), std_logic_vector'("00000000"));
                check_false(slv2mst.has_error);
            elsif run("Reading from mie does not result in error") then
                mst2slv.address <= 16#4#;
                mst2slv.do_read <= true;
                wait for clk_period;
                check_false(slv2mst.has_error);
            elsif run("Setting mie.MTIE enables machine timer interrupt") then
                mst2slv.address <= 16#4#;
                mst2slv.do_read <= true;
                mst2slv.do_write <= true;
                mst2slv.write_data <= x"00000080";
                wait for clk_period;
                check_true(m_timer_interrupt_enabled);
            elsif run("Setting mie.MEIE enables machine external interrupt") then
                mst2slv.address <= 16#4#;
                mst2slv.do_read <= true;
                mst2slv.do_write <= true;
                mst2slv.write_data <= x"00000800";
                wait for clk_period;
                check_true(m_external_interrupt_enabled);
            elsif run("All other bits are readonly zero in mie") then
                mst2slv.address <= 16#4#;
                mst2slv.do_read <= true;
                mst2slv.do_write <= true;
                mst2slv.write_data <= (others => '1');
                wait for clk_period;
                check_equal(slv2mst.read_data, std_logic_vector'(x"00000880"));
            elsif run("Reading from mtvec does not result in error") then
                mst2slv.address <= 16#5#;
                mst2slv.do_read <= true;
                wait for clk_period;
                check_false(slv2mst.has_error);
            elsif run("mtvec.MODE is 1") then
                mst2slv.address <= 16#5#;
                mst2slv.do_read <= true;
                wait for clk_period;
                check_equal(slv2mst.read_data(1 downto 0), std_logic_vector'("01"));
            elsif run("mtvec.BASE can be set") then
                mst2slv.address <= 16#5#;
                mst2slv.do_read <= true;
                mst2slv.write_data <= (others => '1');
                mst2slv.do_write <= true;
                wait for clk_period;
                check_equal(and_reduce(slv2mst.read_data(slv2mst.read_data'high downto 2)), '1');
            elsif run("mtvec.MODE cannot be overwritten") then
                mst2slv.address <= 16#5#;
                mst2slv.do_read <= true;
                mst2slv.write_data <= (others => '1');
                mst2slv.do_write <= true;
                wait for clk_period;
                check_equal(slv2mst.read_data(1 downto 0), std_logic_vector'("01"));
            elsif run("Reading from mstatush does not result in error") then
                mst2slv.address <= 16#10#;
                mst2slv.do_read <= true;
                wait for clk_period;
                check_false(slv2mst.has_error);
            end if;
        end loop;
        test_runner_cleanup(runner);
        wait;
    end process;

    csr_machine_trap_setup : entity src.riscv32_csr_machine_trap_setup
    port map (
        clk => clk,
        rst => rst,
        mst2slv => mst2slv,
        slv2mst => slv2mst,
        interrupts_enabled => interrupts_enabled,
        interrupt_trigger => interrupt_trigger,
        m_timer_interrupt_enabled => m_timer_interrupt_enabled,
        m_external_interrupt_enabled => m_external_interrupt_enabled
    );
end architecture;
