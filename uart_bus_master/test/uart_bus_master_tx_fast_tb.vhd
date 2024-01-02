library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;

entity uart_bus_master_tx_fast_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of uart_bus_master_tx_fast_tb is
    constant clk_period : time := 20 ns;
    constant baud_rate : positive := 5000000;

    constant word_transfer_time : time := (10 sec)/baud_rate;

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal tx : std_logic;

    signal transmit_byte : std_logic_vector(7 downto 0) := (others => '0');
    signal data_ready : boolean := false;
    signal busy : boolean;

    constant uart_bfm : uart_slave_t := new_uart_slave(initial_baud_rate => baud_rate);
    constant uart_stream : stream_slave_t := as_stream(uart_bfm);
begin

    clk <= not clk after (clk_period/2);

    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Fast transmission") then
                transmit_byte <= "01010101";
                data_ready <= true;
                wait until rising_edge(clk) and busy;
                data_ready <= false;
                wait until rising_edge(clk) and not busy;
                check_stream(net, uart_stream, "01010101");
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 ms);

    bus_master_tx : entity src.uart_bus_master_tx
    generic map (
        clk_period => clk_period,
        baud_rate => baud_rate
    ) port map (
        clk => clk,
        rst => rst,
        tx => tx,
        transmit_byte => transmit_byte,
        data_ready => data_ready,
        busy => busy
    );


 uart_slave_bfm : entity vunit_lib.uart_slave
    generic map (
      uart => uart_bfm)
    port map (
      rx => tx);
end architecture;
