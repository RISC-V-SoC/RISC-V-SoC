library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;

entity uart_bus_master_baudgen_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of uart_bus_master_baudgen_tb is
    constant clk_period : time := 20 ns;

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal baud_clk : std_logic;
begin

    clk <= not clk after (clk_period/2);

    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Baud clk is 0 on start") then
                wait until rising_edge(clk);
                check(baud_clk = '0');
            elsif run("Baud clk is 1 after 53 us") then
                wait for 53 us;
                check(baud_clk = '1');
            elsif run("Baud clk is 0 after 105 us") then
                wait for 105 us;
                check(baud_clk = '0');
            elsif run("Baud clk goes to 0 on rst") then
                wait for 53 us;
                rst <= '1';
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check(baud_clk = '0');
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 ms);

    baudgen : entity src.uart_bus_master_baudgen
    generic map (
        clk_period => clk_period,
        baud_rate => 9600
    ) port map (
        clk => clk,
        rst => rst,
        baud_clk => baud_clk
    );
end architecture;
