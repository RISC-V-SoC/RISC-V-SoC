library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.riscv32_pkg;

entity riscv32_control_interface_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_control_interface_tb is
    constant clk_period : time := 20 ns;
    constant clk_frequency : natural := (1 sec)/clk_period;

    signal clk : std_logic := '0';
    signal rst : boolean := false;

    signal address_from_controller : natural range 0 to 31 := 0;

    signal write_from_controller : boolean := false;

    signal data_from_controller : riscv32_pkg.riscv32_data_type := (others => '0');

    signal data_to_controller : riscv32_pkg.riscv32_data_type;

    signal cpu_reset : boolean;
    signal cpu_stall : boolean;

    signal flush_cache : boolean := true;
    signal cache_flush_in_progress : boolean := false;

begin

    clk <= not clk after (clk_period/2);

    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("cpu stall is true before first rising edge") then
                wait until rising_edge(clk);
                check(cpu_stall);
            elsif run("data_to_controller address 0 reads as 2 before first rising edge") then
                address_from_controller <= 0;
                wait until rising_edge(clk);
                check(X"00000002" = data_to_controller);
            elsif run("data_to_controller address 5 reads as 0 before first rising edge") then
                address_from_controller <= 5;
                wait until rising_edge(clk);
                check(X"00000000" = data_to_controller);
            elsif run("Writing 0 to address 0 from data_from_controller drops cpu_reset") then
                wait until falling_edge(clk);
                address_from_controller <= 0;
                data_from_controller <= (others => '0');
                write_from_controller <= true;
                wait until falling_edge(clk);
                check(not cpu_reset);
            elsif run("Read after write from controller returns last written data") then
                wait until falling_edge(clk);
                address_from_controller <= 0;
                data_from_controller <= (others => '0');
                write_from_controller <= true;
                wait until falling_edge(clk);
                write_from_controller <= false;
                wait until rising_edge(clk);
                check(X"00000000" = data_to_controller);
            elsif run("Writing 0 to address 5 from data_from_controller keeps cpu_stall high") then
                wait until falling_edge(clk);
                address_from_controller <= 5;
                data_from_controller <= (others => '0');
                write_from_controller <= true;
                wait until falling_edge(clk);
                check(cpu_stall);
            elsif run("Writing 2 to address 0 disables reset, enables stall") then
                wait until falling_edge(clk);
                address_from_controller <= 0;
                data_from_controller <= X"00000002";
                write_from_controller <= true;
                wait until falling_edge(clk);
                check(not cpu_reset);
                check(cpu_stall);
            elsif run("Only bits 0, 1 and 2 are writable") then
                wait until falling_edge(clk);
                address_from_controller <= 0;
                data_from_controller <= (others => '1');
                write_from_controller <= true;
                wait until falling_edge(clk);
                write_from_controller <= false;
                wait until rising_edge(clk);
                check(data_to_controller = X"00000007");
            elsif run("rst resets") then
                wait until falling_edge(clk);
                address_from_controller <= 0;
                data_from_controller <= X"00000002";
                write_from_controller <= true;
                wait until falling_edge(clk);
                write_from_controller <= false;
                rst <= true;
                wait until falling_edge(clk);
                check(not cpu_reset);
                check(cpu_stall);
            elsif run("Address 1 from controller reads clock frequency") then
                wait until falling_edge(clk);
                address_from_controller <= 1;
                wait until falling_edge(clk);
                check_equal(to_integer(unsigned(data_to_controller)), clk_frequency);
            elsif run("Setting bit 3 in address 0 puts cache_flush high for one cycle") then
                wait until falling_edge(clk);
                address_from_controller <= 0;
                data_from_controller <= (others => '1');
                write_from_controller <= true;
                wait until falling_edge(clk);
                write_from_controller <= false;
                check_true(flush_cache);
                wait for clk_period;
                check_false(flush_cache);
            elsif run("Address 4 bit 0 corresponds to cache_flush_in_progress") then
                cache_flush_in_progress <= false;
                wait until falling_edge(clk);
                address_from_controller <= 4;
                wait until falling_edge(clk);
                check_true(data_to_controller(0) = '0');
                cache_flush_in_progress <= true;
                wait until falling_edge(clk);
                check_true(data_to_controller(0) = '1');
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 us);

    control_interface : entity src.riscv32_control_interface
    generic map (
        clk_period => clk_period
    ) port map (
        clk,
        rst,
        address_from_controller,
        write_from_controller,
        data_from_controller,
        data_to_controller,
        instructionAddress => (others => '0'),
        if_fault => false,
        if_faultData => (others => '0'),
        mem_fault => false,
        mem_faultData => (others => '0'),
        cpu_reset => cpu_reset,
        cpu_stall => cpu_stall,
        flush_cache => flush_cache,
        cache_flush_in_progress => cache_flush_in_progress
    );
end architecture;
