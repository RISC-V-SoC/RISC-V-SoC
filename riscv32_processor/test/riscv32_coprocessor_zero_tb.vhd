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
    signal rst : std_logic := '0';

    signal address_from_controller : natural range 0 to 31 := 0;

    signal write_from_controller : boolean := false;

    signal data_from_controller : riscv32_pkg.riscv32_data_type := (others => '0');

    signal data_to_controller : riscv32_pkg.riscv32_data_type;

    signal cpu_reset : boolean;
    signal cpu_stall : boolean;

begin

    clk <= not clk after (clk_period/2);

    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("cpu reset is true before first rising edge") then
                wait until rising_edge(clk);
                check(cpu_reset);
            elsif run("data_to_controller address 0 reads as 1 before first rising edge") then
                address_from_controller <= 0;
                wait until rising_edge(clk);
                check(X"00000001" = data_to_controller);
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
            elsif run("Writing 0 to address 5 from data_from_controller keep cpu_reset high") then
                wait until falling_edge(clk);
                address_from_controller <= 5;
                data_from_controller <= (others => '0');
                write_from_controller <= true;
                wait until falling_edge(clk);
                check(cpu_reset);
            elsif run("Writing 2 to address 0 disables reset, enables stall") then
                wait until falling_edge(clk);
                address_from_controller <= 0;
                data_from_controller <= X"00000002";
                write_from_controller <= true;
                wait until falling_edge(clk);
                check(not cpu_reset);
                check(cpu_stall);
            elsif run("Only bits 0 and 1 are writable") then
                wait until falling_edge(clk);
                address_from_controller <= 0;
                data_from_controller <= (others => '1');
                write_from_controller <= true;
                wait until falling_edge(clk);
                write_from_controller <= false;
                wait until rising_edge(clk);
                check(data_to_controller = X"00000003");
            elsif run("rst resets") then
                wait until falling_edge(clk);
                address_from_controller <= 0;
                data_from_controller <= X"00000002";
                write_from_controller <= true;
                wait until falling_edge(clk);
                write_from_controller <= false;
                rst <= '1';
                wait until falling_edge(clk);
                check(cpu_reset);
                check(not cpu_stall);
            elsif run("Address 1 from controller reads clock frequency") then
                wait until falling_edge(clk);
                address_from_controller <= 1;
                wait until falling_edge(clk);
                check_equal(to_integer(unsigned(data_to_controller)), clk_frequency);
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
        cpu_reset,
        cpu_stall
    );
end architecture;
