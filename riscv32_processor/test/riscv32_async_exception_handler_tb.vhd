library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg.all;
use src.riscv32_pkg.all;

entity riscv32_async_exception_handler_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_async_exception_handler_tb is
    constant clk_period : time := 20 ns;

    signal clk : std_logic := '0';

    signal async_exception_pending : boolean;
    signal async_exception_code : riscv32_exception_code_type;

    signal machine_interrupts_enabled : boolean := false;

    signal machine_level_external_interrupt_pending : boolean := false;
    signal machine_level_external_interrupt_enabled : boolean := false;

    signal machine_level_timer_interrupt_pending : boolean := false;
    signal machine_level_timer_interrupt_enabled : boolean := false;

    signal machine_level_software_interrupt_pending : boolean := false;
    signal machine_level_software_interrupt_enabled : boolean := false;
begin

    clk <= not clk after (clk_period/2);

    main : process
        variable actualAddress : std_logic_vector(bus_address_type'range);
        variable writeValue : riscv32_data_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("If machine level external interrupt pending, then the right async exception is pending") then
                machine_interrupts_enabled <= true;
                machine_level_external_interrupt_enabled <= true;
                machine_level_external_interrupt_pending <= true;
                wait until falling_edge(clk);
                check(async_exception_pending);
                check(async_exception_code = riscv32_exception_code_machine_external_interrupt);
            elsif run("If machine level external interrupt pending but disabled, no async exception is pending") then
                machine_interrupts_enabled <= true;
                machine_level_external_interrupt_enabled <= false;
                machine_level_external_interrupt_pending <= true;
                wait until falling_edge(clk);
                check(not async_exception_pending);
            elsif run("If machine level external interrupt not pending and enabled, no async exception is pending") then
                machine_interrupts_enabled <= true;
                machine_level_external_interrupt_enabled <= true;
                machine_level_external_interrupt_pending <= false;
                wait until falling_edge(clk);
                check(not async_exception_pending);
            elsif run("If global interrupts disabled, no async exception is pending") then
                machine_interrupts_enabled <= false;
                machine_level_external_interrupt_enabled <= true;
                machine_level_external_interrupt_pending <= true;
                machine_level_software_interrupt_enabled <= true;
                machine_level_software_interrupt_pending <= true;
                machine_level_timer_interrupt_enabled <= true;
                machine_level_timer_interrupt_pending <= true;
                wait until falling_edge(clk);
                check(not async_exception_pending);
            elsif run("Check priority order using enabled") then
                machine_interrupts_enabled <= true;
                machine_level_external_interrupt_enabled <= true;
                machine_level_external_interrupt_pending <= true;
                machine_level_software_interrupt_enabled <= true;
                machine_level_software_interrupt_pending <= true;
                machine_level_timer_interrupt_enabled <= true;
                machine_level_timer_interrupt_pending <= true;
                wait until falling_edge(clk);
                check(async_exception_pending);
                check(async_exception_code = riscv32_exception_code_machine_external_interrupt);
                machine_level_external_interrupt_enabled <= false;
                wait until falling_edge(clk);
                check(async_exception_pending);
                check(async_exception_code = riscv32_exception_code_machine_software_interrupt);
                machine_level_software_interrupt_enabled <= false;
                wait until falling_edge(clk);
                check(async_exception_pending);
                check(async_exception_code = riscv32_exception_code_machine_timer_interrupt);
                machine_level_timer_interrupt_enabled <= false;
                wait until falling_edge(clk);
                check(not async_exception_pending);
            elsif run("Check priority order using pending") then
                machine_interrupts_enabled <= true;
                machine_level_external_interrupt_enabled <= true;
                machine_level_external_interrupt_pending <= true;
                machine_level_software_interrupt_enabled <= true;
                machine_level_software_interrupt_pending <= true;
                machine_level_timer_interrupt_enabled <= true;
                machine_level_timer_interrupt_pending <= true;
                wait until falling_edge(clk);
                check(async_exception_pending);
                check(async_exception_code = riscv32_exception_code_machine_external_interrupt);
                machine_level_external_interrupt_pending <= false;
                wait until falling_edge(clk);
                check(async_exception_pending);
                check(async_exception_code = riscv32_exception_code_machine_software_interrupt);
                machine_level_software_interrupt_pending <= false;
                wait until falling_edge(clk);
                check(async_exception_pending);
                check(async_exception_code = riscv32_exception_code_machine_timer_interrupt);
                machine_level_timer_interrupt_pending <= false;
                wait until falling_edge(clk);
                check(not async_exception_pending);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 us);

    async_exception_handler : entity src.riscv32_async_exception_handler
    port map (
        clk => clk,
        async_exception_pending => async_exception_pending,
        async_exception_code => async_exception_code,
        machine_interrupts_enabled => machine_interrupts_enabled,
        machine_level_external_interrupt_pending => machine_level_external_interrupt_pending,
        machine_level_external_interrupt_enabled => machine_level_external_interrupt_enabled,
        machine_level_timer_interrupt_pending => machine_level_timer_interrupt_pending,
        machine_level_timer_interrupt_enabled => machine_level_timer_interrupt_enabled,
        machine_level_software_interrupt_pending => machine_level_software_interrupt_pending,
        machine_level_software_interrupt_enabled => machine_level_software_interrupt_enabled
    );
end architecture;
