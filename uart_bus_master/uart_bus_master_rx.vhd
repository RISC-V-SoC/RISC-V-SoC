library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart_bus_master_rx is
    generic (
        clk_period : time;
        baud_rate : positive
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        rx : in std_logic;

        receive_byte : out std_logic_vector(7 downto 0);
        data_ready : out boolean
    );
end entity;

architecture behaviourial of uart_bus_master_rx is
    signal baud_clk_rst : std_logic := '1';
    signal baud_clk : std_logic;
    signal count_buf : natural range 0 to 9 := 0;
begin
    process(clk)
        variable count : natural range 0 to 9 := 0;
        variable receive_byte_buf : std_logic_vector(7 downto 0);
        variable last_baud_clk : std_logic := '0';
        variable baud_clk_rst_buf : boolean := true;
        variable data_ready_buf : boolean := false;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                count := 0;
                baud_clk_rst_buf := true;
                data_ready_buf := false;
            elsif count = 0 then
                data_ready_buf := false;
                if last_baud_clk = '1' and baud_clk = '0' and not baud_clk_rst_buf then
                    count := count + 1;
                end if;
                if rx = '0' then
                    baud_clk_rst_buf := false;
                end if;
            elsif count < 9 then
                if last_baud_clk = '0' and baud_clk = '1' then
                    receive_byte_buf(count - 1) := rx;
                elsif last_baud_clk = '1' and baud_clk = '0' then
                    count := count + 1;
                end if;
            else
                if last_baud_clk = '0' and baud_clk = '1' then
                    baud_clk_rst_buf := true;
                    if rx = '1' then
                        data_ready_buf := true;
                    end if;
                    count := 0;
                end if;
            end if;
            last_baud_clk := baud_clk;
        end if;
        baud_clk_rst <= '1' when baud_clk_rst_buf else '0';
        receive_byte <= receive_byte_buf;
        data_ready <= data_ready_buf;
        count_buf <= count;
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
