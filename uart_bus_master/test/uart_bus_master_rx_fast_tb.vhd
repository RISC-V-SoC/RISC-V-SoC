library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;

entity uart_bus_master_rx_fast_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of uart_bus_master_rx_fast_tb is
    constant clk_period : time := 20 ns;
    constant baud_rate : positive := 5000000;

    constant word_transfer_time : time := (10 sec)/baud_rate;

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal rx : std_logic := '1';

    signal override_rx : boolean := false;

    signal manual_rx : std_logic := '1';
    signal verification_rx : std_logic := '1';

    signal receive_byte : std_logic_vector(7 downto 0);
    signal data_ready : boolean;

    constant uart_bfm : uart_master_t := new_uart_master(initial_baud_rate => baud_rate);
    constant uart_stream : stream_master_t := as_stream(uart_bfm);
begin

    clk <= not clk after (clk_period/2);

    rx <= verification_rx when not override_rx else manual_rx;

    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("test fast receive") then
                wait for clk_period/2;
                push_stream(net, uart_stream, "01010101");
                wait until rising_edge(clk) and data_ready;
                check(receive_byte = "01010101");
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  2*word_transfer_time);

    bus_master_rx : entity src.uart_bus_master_rx
    generic map (
        clk_period => clk_period,
        baud_rate => baud_rate
    ) port map (
        clk => clk,
        rst => rst,
        rx => rx,
        receive_byte => receive_byte,
        data_ready => data_ready
    );


    uart_master_bfm : entity vunit_lib.uart_master
    generic map (
      uart => uart_bfm)
    port map (
      tx => verification_rx);
end architecture;
