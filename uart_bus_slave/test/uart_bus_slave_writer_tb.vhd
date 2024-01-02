library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;

entity uart_bus_slave_writer_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of uart_bus_slave_writer_tb is
    constant uart_slave_bfm : uart_slave_t := new_uart_slave(initial_baud_rate => 115200);
    constant uart_slave_stream : stream_slave_t := as_stream(uart_slave_bfm);
    constant clk_period : time := 20 ns;
    signal clk : std_logic := '0';
    signal reset : boolean := false;
    signal half_baud_clk_ticks : unsigned(31 downto 0) := (others => '0');
    signal tx : std_logic := '0';
    signal data_in : std_logic_vector(7 downto 0);
    signal data_available : boolean := false;
    signal data_pop : boolean;

    signal received_data : std_logic_vector(7 downto 0) := (others => '0');
begin
    clk <= not clk after (clk_period/2);
    process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("tx starts at logical one") then
                assert(tx = '1');
            elsif run("tx drops when data is available") then
                data_available <= true;
                wait for clk_period;
                assert(tx = '0');
            elsif run("writer pops data correctly") then
                data_available <= true;
                wait until rising_edge(clk) and data_pop;
                wait until rising_edge(clk);
                check(not data_pop);
            elsif run("Transfer one word") then
                reset <= true;
                half_baud_clk_ticks <= to_unsigned(217, half_baud_clk_ticks'length);
                wait until falling_edge(clk);
                reset <= false;
                data_in <= X"45";
                data_available <= true;
                wait until rising_edge(clk) and data_pop;
                data_available <= false;
                check_stream(net, uart_slave_stream, X"45");
                assert(tx = '1');
            elsif run("Transfer two words back to back") then
                reset <= true;
                half_baud_clk_ticks <= to_unsigned(217, half_baud_clk_ticks'length);
                wait until falling_edge(clk);
                reset <= false;
                data_in <= X"45";
                data_available <= true;
                wait until rising_edge(clk) and data_pop;
                data_in <= X"56";
                wait until rising_edge(clk) and data_pop;
                data_available <= false;
                check_stream(net, uart_slave_stream, X"45");
                check_stream(net, uart_slave_stream, X"56");
            end if;
        end loop;
        wait until rising_edge(clk) or falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 1 ms);

    uart_bus_slave_writer : entity src.uart_bus_slave_writer
    port map (
        clk => clk,
        reset => reset,
        half_baud_clk_ticks => half_baud_clk_ticks,
        tx => tx,
        data_in => data_in,
        data_available => data_available,
        data_pop => data_pop
    );

    uart_slave : entity vunit_lib.uart_slave
    generic map (
      uart => uart_slave_bfm)
    port map (
      rx => tx);
end architecture;
