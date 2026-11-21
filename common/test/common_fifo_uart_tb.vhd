library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;

entity common_fifo_uart_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of common_fifo_uart_tb is
    constant uart_slave_bfm : uart_slave_t := new_uart_slave(initial_baud_rate => 115200);
    constant uart_slave_stream : stream_slave_t := as_stream(uart_slave_bfm);
    constant uart_master_bfm : uart_master_t := new_uart_master(initial_baud_rate => 115200);
    constant uart_master_stream : stream_master_t := as_stream(uart_master_bfm);
    constant clk_period : time := 20 ns;
    constant receive_depth_log2b : natural := 3;
    constant transmit_depth_log2b : natural := 4;
    constant receive_depth : natural := 2**receive_depth_log2b;
    constant transmit_depth : natural := 2**transmit_depth_log2b;

    signal clk : std_logic := '0';
    signal reset : boolean := false;

    signal rx : std_logic := '0';
    signal tx : std_logic;

    signal baud_clk_ticks : unsigned(31 downto 0);

    signal rx_enabled : boolean := true;
    signal tx_enabled : boolean := true;

    signal receive_data : std_ulogic_vector(7 downto 0);
    signal receive_data_pop : boolean;
    signal receive_fifo_almost_empty : boolean;
    signal receive_fifo_empty : boolean;
    signal receive_fifo_overflow : boolean;
    signal receive_fifo_count : natural range 0 to receive_depth;

    signal transmit_data : std_ulogic_vector(7 downto 0);
    signal transmit_data_push : boolean;
    signal transmit_fifo_almost_full : boolean;
    signal transmit_fifo_full : boolean;
    signal transmit_fifo_count : natural range 0 to transmit_depth;
begin
    clk <= not clk after (clk_period/2);
    process
        variable num : unsigned(7 downto 0) := (others => '0');
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Fill out transmit queue") then
                reset <= true;
                baud_clk_ticks <= to_unsigned(434, baud_clk_ticks'length);
                wait until falling_edge(clk);
                reset <= false;
                while not transmit_fifo_almost_full loop
                    transmit_data <= std_ulogic_vector(num);
                    transmit_data_push <= true;
                    wait until rising_edge(clk);
                    num := num + 1;
                end loop;
                transmit_data_push <= false;
                wait until rising_edge(clk);
                check_equal(transmit_fifo_count, transmit_depth);
                check_true(transmit_fifo_full);
                for i in 0 to to_integer(num - 1) loop
                    check_stream(net, uart_slave_stream, std_logic_vector(to_unsigned(i, 8)));
                end loop;
            elsif run("Fill out receive queue") then
                reset <= true;
                baud_clk_ticks <= to_unsigned(434, baud_clk_ticks'length);
                wait until falling_edge(clk);
                reset <= false;
                for i in 0 to receive_depth - 1 loop
                    push_stream(net, uart_master_stream, std_logic_vector(to_unsigned(i, 8)));
                end loop;
                wait until rising_edge(clk) and receive_fifo_count = receive_depth;
                check_false(receive_fifo_almost_empty);
                check_false(receive_fifo_empty);
                for i in 0 to receive_depth - 1 loop
                    receive_data_pop <= true;
                    wait until rising_edge(clk);
                    check_equal(receive_data, std_logic_vector(to_unsigned(i, 8)));
                end loop;
                check_true(receive_fifo_almost_empty);
                wait until rising_edge(clk);
                check_true(receive_fifo_empty);
            end if;
        end loop;
        wait until rising_edge(clk) or falling_edge(clk);
        test_runner_cleanup(runner);
    end process;

    test_runner_watchdog(runner, 10 ms);

    common_fifo_uart : entity src.common_fifo_uart
    generic map (
        receive_fifo_depth_log2b => receive_depth_log2b,
        transmit_fifo_depth_log2b => transmit_depth_log2b
    ) port map (
        clk => clk,
        reset => reset,
        rx => rx,
        tx => tx,
        baud_clk_ticks => baud_clk_ticks,
        rx_enabled => rx_enabled,
        tx_enabled => tx_enabled,
        receive_data => receive_data,
        receive_data_pop => receive_data_pop,
        receive_fifo_almost_empty => receive_fifo_almost_empty,
        receive_fifo_empty => receive_fifo_empty,
        receive_fifo_overflow => receive_fifo_overflow,
        receive_fifo_count => receive_fifo_count,
        transmit_data => transmit_data,
        transmit_data_push => transmit_data_push,
        transmit_fifo_almost_full => transmit_fifo_almost_full,
        transmit_fifo_full => transmit_fifo_full,
        transmit_fifo_count => transmit_fifo_count
    );

    uart_slave : entity vunit_lib.uart_slave
    generic map (
      uart => uart_slave_bfm)
    port map (
      rx => tx);

    uart_master : entity vunit_lib.uart_master
    generic map (
      uart => uart_master_bfm)
    port map (
      tx => rx);
end architecture;
