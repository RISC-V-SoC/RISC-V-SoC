library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;

entity uart_bus_master_rx_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of uart_bus_master_rx_tb is
    constant clk_period : time := 20 ns;
    constant baud_rate : positive := 115200;

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
            if run("test receive byte 57") then
                push_stream(net, uart_stream, x"57");
                wait until rising_edge(clk) and data_ready;
                check(receive_byte = X"57");
            elsif run("test receive multiple bytes") then
                push_stream(net, uart_stream, x"00");
                push_stream(net, uart_stream, x"10");
                push_stream(net, uart_stream, x"54");
                push_stream(net, uart_stream, x"ff");
                wait until rising_edge(clk) and data_ready;
                check(receive_byte = X"00");
                wait until rising_edge(clk) and data_ready;
                check(receive_byte = X"10");
                wait until rising_edge(clk) and data_ready;
                check(receive_byte = X"54");
                wait until rising_edge(clk) and data_ready;
                check(receive_byte = X"ff");
            elsif run("Wrong stop bit means no data_ready") then
                manual_rx <= '0';
                override_rx <= true;
                wait until data_ready'event for 1.5*word_transfer_time;
                check(not data_ready);
            elsif run("No communication when rst is active") then
                rst <= '1';
                push_stream(net, uart_stream, x"57");
                wait until data_ready'event for 1.5*word_transfer_time;
                check(not data_ready);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 ms);

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
