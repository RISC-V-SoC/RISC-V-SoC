library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;

entity uart_bus_slave_reader_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of uart_bus_slave_reader_tb is
    constant uart_master_bfm : uart_master_t := new_uart_master(initial_baud_rate => 115200);
    constant uart_master_stream : stream_master_t := as_stream(uart_master_bfm);
    constant clk_period : time := 20 ns;
    signal clk : std_logic := '0';
    signal reset : boolean := false;
    signal half_baud_clk_ticks : unsigned(31 downto 0) := (others => '0');
    signal rx : std_logic := '0';
    signal data_out : std_logic_vector(7 downto 0);
    signal data_ready : boolean;

    signal received_data : std_logic_vector(7 downto 0) := (others => '0');
begin
    clk <= not clk after (clk_period/2);
    process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Write word") then
                reset <= true;
                half_baud_clk_ticks <= to_unsigned(217, half_baud_clk_ticks'length);
                wait until falling_edge(clk);
                reset <= false;
                wait until rising_edge(clk);
                push_stream(net, uart_master_stream, X"ab");
                wait until rising_edge(clk) and data_ready;
                check_equal(data_out, std_logic_vector'(X"ab"));
            elsif run("Write two words back to back") then
                set_baud_rate(net, uart_master_bfm, 230400);
                reset <= true;
                half_baud_clk_ticks <= to_unsigned(109, half_baud_clk_ticks'length);
                wait until falling_edge(clk);
                reset <= false;
                push_stream(net, uart_master_stream, X"12");
                wait until rising_edge(clk) and data_ready;
                check_equal(data_out, std_logic_vector'(X"12"));
                wait until rising_edge(clk) and not data_ready;
                push_stream(net, uart_master_stream, X"ff");
                wait until rising_edge(clk) and data_ready;
                check_equal(data_out, std_logic_vector'(X"ff"));
            end if;
        end loop;
        wait until rising_edge(clk) or falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 1 ms);

    process(clk)
    begin
        if rising_edge(clk) and data_ready then
            received_data <= data_out;
        end if;
    end process;

    uart_bus_slave_reader : entity src.uart_bus_slave_reader
    port map (
        clk => clk,
        reset => reset,
        half_baud_clk_ticks => half_baud_clk_ticks,
        rx => rx,
        data_out => data_out,
        data_ready => data_ready
    );

    uart_master : entity vunit_lib.uart_master
    generic map (
      uart => uart_master_bfm)
    port map (
      tx => rx);
end architecture;
