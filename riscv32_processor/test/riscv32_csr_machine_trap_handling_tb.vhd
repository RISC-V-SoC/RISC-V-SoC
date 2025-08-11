library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.riscv32_pkg.all;

entity riscv32_csr_machine_trap_handling_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_csr_machine_trap_handling_tb is
        constant clk_period : time := 20 ns;
        signal clk : std_logic := '0';
        signal rst : boolean := false;

        signal mst2slv : riscv32_csr_mst2slv_type;
        signal slv2mst : riscv32_csr_slv2mst_type;

        signal machine_timer_interrupt_pending : boolean := false;
        signal machine_external_interrupt_pending : boolean := false;

        signal interrupt_is_async : boolean := false;
        signal exception_code : riscv32_exception_code_type := 0;

        signal interrupted_pc : riscv32_address_type := (others => '0');
        signal pc_on_return : riscv32_address_type;

        signal interrupt_trigger : boolean := false;
begin
    clk <= not clk after (clk_period/2);
    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Read from address 0x45 results in error") then
                mst2slv.address <= 16#45#;
                mst2slv.do_read <= true;
                wait for 10 ns;
                check_true(slv2mst.has_error);
            elsif run("Read from address 0x40 does not result in error") then
                mst2slv.address <= 16#40#;
                mst2slv.do_read <= true;
                wait for 10 ns;
                check_false(slv2mst.has_error);
            elsif run("Check write-then-read mscratch") then
                mst2slv.address <= 16#40#;
                mst2slv.do_write <= true;
                mst2slv.write_data <= x"12345678";
                wait for clk_period;
                mst2slv.do_write <= false;
                mst2slv.do_read <= true;
                wait for 10 ns;
                check_equal(slv2mst.read_data, std_logic_vector'(x"12345678"));
            elsif run("Writing to address 0x45 does not update mscratch") then
                mst2slv.address <= 16#45#;
                mst2slv.do_write <= true;
                mst2slv.write_data <= x"12345678";
                wait for 10 ns;
                mst2slv.do_write <= false;
                mst2slv.address <= 16#40#;
                mst2slv.do_read <= true;
                wait for 10 ns;
                check_equal(slv2mst.read_data, std_logic_vector'(x"00000000"));
            elsif run("Rst sets mscratch too all zeros") then
                mst2slv.address <= 16#40#;
                mst2slv.do_write <= true;
                mst2slv.write_data <= x"12345678";
                wait for clk_period;
                rst <= true;
                mst2slv.do_write <= false;
                wait for clk_period;
                rst <= false;
                mst2slv.address <= 16#40#;
                mst2slv.do_read <= true;
                wait for 10 ns;
                check_equal(slv2mst.read_data, std_logic_vector'(x"00000000"));
            elsif run("Read from address 0x41 does not result in error") then
                mst2slv.address <= 16#41#;
                mst2slv.do_read <= true;
                wait for 10 ns;
                check_false(slv2mst.has_error);
            elsif run("Check write-then-read mepc") then
                mst2slv.address <= 16#41#;
                mst2slv.do_write <= true;
                mst2slv.write_data <= x"f0f0f0f0";
                wait for clk_period;
                mst2slv.do_write <= false;
                mst2slv.do_read <= true;
                wait for 10 ns;
                check_equal(slv2mst.read_data, std_logic_vector'(x"f0f0f0f0"));
            elsif run("Lower 2 bits of mepc are always zero") then
                mst2slv.address <= 16#41#;
                mst2slv.do_write <= true;
                mst2slv.write_data <= x"ffffffff";
                wait for clk_period;
                mst2slv.do_write <= false;
                mst2slv.address <= 16#41#;
                mst2slv.do_read <= true;
                wait for 10 ns;
                check_equal(slv2mst.read_data, std_logic_vector'(x"fffffffc"));
            elsif run("Rst resets mepc") then
                mst2slv.address <= 16#41#;
                mst2slv.do_write <= true;
                mst2slv.write_data <= x"f0f0f0f0";
                wait for clk_period;
                rst <= true;
                mst2slv.do_write <= false;
                wait for clk_period;
                rst <= false;
                mst2slv.address <= 16#41#;
                mst2slv.do_read <= true;
                wait for 10 ns;
                check_equal(slv2mst.read_data, std_logic_vector'(x"00000000"));
            elsif run("mepc controls pc_on_return") then
                mst2slv.address <= 16#41#;
                mst2slv.do_write <= true;
                mst2slv.write_data <= x"12345670";
                wait for clk_period;
                mst2slv.do_write <= false;
                mst2slv.address <= 16#41#;
                mst2slv.do_read <= true;
                wait for 10 ns;
                check_equal(pc_on_return, std_logic_vector'(x"12345670"));
            elsif run("On interrupt, interrupted_pc is copied into mepc") then
                interrupted_pc <= x"10203040";
                interrupt_trigger <= true;
                wait for clk_period;
                interrupt_trigger <= false;
                mst2slv.address <= 16#41#;
                mst2slv.do_read <= true;
                wait for 10 ns;
                check_equal(slv2mst.read_data, interrupted_pc);
            elsif run("Read from address 0x42 does not result in error") then
                mst2slv.address <= 16#42#;
                mst2slv.do_read <= true;
                wait for 10 ns;
                check_false(slv2mst.has_error);
            elsif run("Interrupt_is_async is clocked in on interrupt") then
                interrupt_is_async <= true;
                interrupt_trigger <= true;
                wait for clk_period;
                interrupt_trigger <= false;
                mst2slv.address <= 16#42#;
                mst2slv.do_read <= true;
                wait for 10 fs;
                check_equal(slv2mst.read_data(31), '1');
            elsif run("Interrupt_is_async is not clocked in when there is no interrupt") then
                interrupt_is_async <= true;
                interrupt_trigger <= false;
                wait for clk_period;
                mst2slv.address <= 16#42#;
                mst2slv.do_read <= true;
                wait for 10 fs;
                check_equal(slv2mst.read_data(31), '0');
            elsif run("If not interrupt_is_async and interrupt, then mcause.interrupt is zero") then
                interrupt_is_async <= false;
                interrupt_trigger <= true;
                wait for clk_period;
                mst2slv.address <= 16#42#;
                mst2slv.do_read <= true;
                wait for 10 fs;
                check_equal(slv2mst.read_data(31), '0');
            elsif run("If there is an interrupt, the exception code is clocked into mcause.exception_code") then
                exception_code <= 42;
                interrupt_trigger <= true;
                wait for clk_period;
                mst2slv.address <= 16#42#;
                mst2slv.do_read <= true;
                wait for 10 fs;
                check_equal(slv2mst.read_data(slv2mst.read_data'high - 1 downto 0), std_logic_vector(to_unsigned(42, slv2mst.read_data'length - 1)));
            elsif run("If there is no interrupt, the exception code is not clocked into mcause.exception_code") then
                exception_code <= 42;
                interrupt_trigger <= false;
                wait for clk_period;
                mst2slv.address <= 16#42#;
                mst2slv.do_read <= true;
                wait for 10 fs;
                check_equal(slv2mst.read_data(slv2mst.read_data'high - 1 downto 0), std_logic_vector(to_unsigned(0, slv2mst.read_data'length - 1)));
            elsif run("Rst resets mcause") then
                exception_code <= 42;
                interrupt_is_async <= true;
                interrupt_trigger <= true;
                wait for clk_period;
                rst <= true;
                interrupt_trigger <= false;
                wait for clk_period;
                mst2slv.address <= 16#42#;
                mst2slv.do_read <= true;
                wait for 10 fs;
                check_equal(or_reduce(slv2mst.read_data), '0');
            elsif run("Reading from mtval does not result in error") then
                mst2slv.address <= 16#43#;
                mst2slv.do_read <= true;
                wait for 10 ns;
                check_false(slv2mst.has_error);
            elsif run("Reading from mip does not result in error") then
                mst2slv.address <= 16#44#;
                mst2slv.do_read <= true;
                wait for 10 ns;
                check_false(slv2mst.has_error);
            elsif run("mip.mtip is high when machine_timer_interrupt_pending is high") then
                machine_timer_interrupt_pending <= true;
                mst2slv.address <= 16#44#;
                mst2slv.do_read <= true;
                wait for 10 ns;
                check_equal(slv2mst.read_data(7), '1');
            elsif run("mip.mtip is low when machine_timer_interrupt_pending is low") then
                machine_timer_interrupt_pending <= false;
                mst2slv.address <= 16#44#;
                mst2slv.do_read <= true;
                wait for 10 ns;
                check_equal(slv2mst.read_data(7), '0');
            elsif run("mip.meip is high when machine_external_interrupt_pending is high") then
                machine_external_interrupt_pending <= true;
                mst2slv.address <= 16#44#;
                mst2slv.do_read <= true;
                wait for 10 ns;
                check_equal(slv2mst.read_data(11), '1');
            elsif run("mip.meip is low when machine_external_interrupt_pending is low") then
                machine_external_interrupt_pending <= false;
                mst2slv.address <= 16#44#;
                mst2slv.do_read <= true;
                wait for 10 ns;
                check_equal(slv2mst.read_data(11), '0');
            elsif run("Reading from mtinst does not result in error") then
                mst2slv.address <= 16#4A#;
                mst2slv.do_read <= true;
                wait for 10 ns;
                check_false(slv2mst.has_error);
            elsif run("Reading from mtval2 does not result in error") then
                mst2slv.address <= 16#4B#;
                mst2slv.do_read <= true;
                wait for 10 ns;
                check_false(slv2mst.has_error);
            end if;
        end loop;
        test_runner_cleanup(runner);
        wait;
    end process;

    csr_machine_trap_handling : entity src.riscv32_csr_machine_trap_handling
    port map (
        clk => clk,
        rst => rst,
        mst2slv => mst2slv,
        slv2mst => slv2mst,
        machine_timer_interrupt_pending => machine_timer_interrupt_pending,
        machine_external_interrupt_pending => machine_external_interrupt_pending,
        interrupt_is_async => interrupt_is_async,
        exception_code => exception_code,
        interrupted_pc => interrupted_pc,
        pc_on_return => pc_on_return,
        interrupt_trigger => interrupt_trigger
    );
end architecture;
