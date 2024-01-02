library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart_bus_master_tx is
    generic (
        clk_period : time;
        baud_rate : positive
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        tx : out std_logic;

        transmit_byte : in std_logic_vector(7 downto 0);
        data_ready : in boolean;
        busy : out boolean
    );
end entity;

architecture behaviourial of uart_bus_master_tx is
    signal baud_clk_rst : std_logic := '1';
    signal baud_clk : std_logic;
begin

    process(clk)
        variable count : natural range 0 to 9 := 0;
        variable transmit_byte_buf : std_logic_vector(7 downto 0);
        variable last_baud_clk : std_logic := '0';
        variable busy_buf : boolean := false;
        variable tx_buf : std_logic := '1';
    begin
        if rising_edge(clk) then
            if rst = '1' then
                count := 0;
                busy_buf := false;
            elsif count = 0 then
                if data_ready and not busy_buf then
                    busy_buf := true;
                    transmit_byte_buf := transmit_byte;
                elsif busy_buf then
                    tx_buf := '0';
                end if;
                if last_baud_clk = '1' and baud_clk = '0' and busy_buf then
                    count := count + 1;
                end if;
            elsif count < 9 then
                tx_buf := transmit_byte_buf(count - 1);
                if last_baud_clk = '1' and baud_clk = '0' then
                    count := count + 1;
                end if;
            else
                tx_buf := '1';
                if last_baud_clk = '1' and baud_clk = '0' then
                    busy_buf := false;
                    count := 0;
                end if;
            end if;
            last_baud_clk := baud_clk;
        end if;
        baud_clk_rst <= '0' when busy_buf else '1';
        busy <= busy_buf;
        tx <= tx_buf;
    end process;

    baudgen : entity work.uart_bus_master_baudgen
    generic map (
        clk_period => clk_period,
        baud_rate => baud_rate
    ) port map (
        clk => clk,
        rst => baud_clk_rst,
        baud_clk => baud_clk
    );
end architecture;
