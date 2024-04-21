library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.bus_pkg;

entity spi_master_bus_slave_slave is
    port (
        clk : in std_logic;
        miso : in std_logic;
        spi_clk : in std_logic;

        is_enabled : in boolean;
        shift_on_rising_edge : in boolean;

        data_out : out std_logic_vector(7 downto 0);
        data_ready : out boolean
    );
end entity;

architecture behavioral of spi_master_bus_slave_slave is
begin
    process(clk)
        variable byte_count : natural range 0 to 8 := 0;
        variable last_known_spi_clk : std_logic := '0';
        variable data_buf : std_logic_vector(7 downto 0);
        variable enable_cycle : boolean := true;
    begin
        if rising_edge(clk) then
            if not is_enabled then
                enable_cycle := true;
                byte_count := 0;
            elsif enable_cycle then
                enable_cycle := false;
                last_known_spi_clk := spi_clk;
            else
                if last_known_spi_clk = '0' and spi_clk = '1' and not shift_on_rising_edge then
                    data_buf := data_buf(6 downto 0) & miso;
                    byte_count := byte_count + 1;
                elsif last_known_spi_clk = '1' and spi_clk = '0' and shift_on_rising_edge then
                    data_buf := data_buf(6 downto 0) & miso;
                    byte_count := byte_count + 1;
                end if;
                last_known_spi_clk := spi_clk;

                if byte_count = 8 then
                    data_ready <= true;
                    byte_count := 0;
                else
                    data_ready <= false;
                end if;
            end if;
        end if;
        data_out <= data_buf;
    end process;
end architecture;
