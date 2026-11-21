library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity common_fifo_uart is
    generic (
        receive_fifo_depth_log2b : natural range 3 to natural'high := 4;
        transmit_fifo_depth_log2b : natural range 3 to natural'high := 4
    );
    port (
        clk : in std_logic;
        reset : in boolean;

        rx : in std_logic;
        tx : out std_logic;

        baud_clk_ticks : in unsigned(31 downto 0);

        rx_enabled : in boolean;
        tx_enabled : in boolean;

        receive_data : out std_ulogic_vector(7 downto 0);
        receive_data_pop : in boolean;
        receive_fifo_almost_empty : out boolean;
        receive_fifo_empty : out boolean;
        receive_fifo_overflow : out boolean;
        receive_fifo_count : out natural range 0 to 2**receive_fifo_depth_log2b;

        transmit_data : in std_ulogic_vector(7 downto 0);
        transmit_data_push : in boolean;
        transmit_fifo_almost_full : out boolean;
        transmit_fifo_full : out boolean;
        transmit_fifo_count : out natural range 0 to 2**transmit_fifo_depth_log2b
    );
end entity;

architecture behavioral of common_fifo_uart is
    signal half_baud_clk_ticks : unsigned(31 downto 0);

    signal transmit_fifo_empty : boolean;
    signal transmit_fifo_data_out : std_logic_vector(7 downto 0);
    signal transmit_fifo_pop : boolean;

    signal receive_fifo_data_in : std_logic_vector(7 downto 0);
    signal receive_fifo_push : boolean;
begin

    half_baud_clk_ticks <= '0' & baud_clk_ticks(31 downto 1);

    transmit_fifo : entity work.generic_fifo
    generic map (
        depth_log2b => transmit_fifo_depth_log2b,
        word_size_log2b => 3
    )
    port map (
        clk => clk,
        reset => reset or not tx_enabled,
        empty => transmit_fifo_empty,
        full => transmit_fifo_full,
        almost_full => transmit_fifo_almost_full,
        data_in => transmit_data,
        push_data => transmit_data_push,
        data_out => transmit_fifo_data_out,
        pop_data => transmit_fifo_pop,
        count => transmit_fifo_count
    );

    uart_tx : entity work.common_uart_tx
    port map (
        clk => clk,
        reset => reset or not tx_enabled,
        half_baud_clk_ticks => half_baud_clk_ticks,
        tx => tx,
        data_in => transmit_fifo_data_out,
        data_available => not transmit_fifo_empty,
        data_pop => transmit_fifo_pop
    );

    receive_fifo : entity work.generic_fifo
    generic map (
        depth_log2b => receive_fifo_depth_log2b,
        word_size_log2b => 3
    )
    port map (
        clk => clk,
        reset => reset or not rx_enabled,
        empty => receive_fifo_empty,
        almost_empty => receive_fifo_almost_empty,

        data_in => receive_fifo_data_in,
        push_data => receive_fifo_push,
        data_out => receive_data,
        pop_data => receive_data_pop,
        overflow => receive_fifo_overflow,
        count => receive_fifo_count
    );

    uart_rx : entity work.common_uart_rx
    port map (
        clk => clk,
        reset => reset or not rx_enabled,
        half_baud_clk_ticks => half_baud_clk_ticks,
        rx => rx,
        data_out => receive_fifo_data_in,
        data_ready => receive_fifo_push
    );
end architecture;
