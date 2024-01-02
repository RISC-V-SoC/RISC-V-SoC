library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart_bus_master_baudgen is
    generic (
        clk_period : time;
        baud_rate : positive
    );
    port (
        clk : in std_logic;
        rst : in std_logic;
        baud_clk : out std_logic
    );
end entity;

architecture behaviourial of uart_bus_master_baudgen is
    constant baud_period : time := (1 sec)/baud_rate;
    constant baud_half_period : time := baud_period / 2;
    constant baud_half_period_ticks : positive range 5 to positive'high := (baud_half_period + (clk_period/2))/clk_period;

    signal half_period_tick : std_logic;
begin
    process(clk)
        variable baud_clk_buf : std_logic := '0';
    begin
        if rising_edge(clk) then
            if rst = '1' then
                baud_clk_buf := '0';
            elsif (half_period_tick = '1') then
                if baud_clk_buf = '1' then
                    baud_clk_buf := '0';
                else
                    baud_clk_buf := '1';
                end if;
            end if;
        end if;
        baud_clk <= baud_clk_buf;
    end process;

    baud_ticker : entity work.simple_multishot_timer
    generic map (
        match_val => baud_half_period_ticks,
        reset_val => 2
    ) port map (
        clk => clk,
        rst => rst,
        done => half_period_tick
    );


end architecture;
