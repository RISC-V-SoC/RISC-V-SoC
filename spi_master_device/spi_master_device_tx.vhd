library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.bus_pkg;

entity spi_master_device_tx is
    port (
        clk : in std_logic;
        mosi : out std_logic;
        spi_clk : in std_logic;

        is_enabled : in boolean;
        shift_on_rising_edge : in boolean;

        spi_clk_enable : out boolean;
        data_in : in std_logic_vector(7 downto 0);
        data_available : in boolean;
        data_pop : out boolean
    );
end entity;

architecture behavioral of spi_master_device_tx is
begin
    process(clk)
        variable started : boolean := false;
        variable edge_count : natural range 0 to 16 := 0;
        variable data : std_logic_vector(7 downto 0);
        variable last_known_spi_clk : std_logic;
        variable start_detected : boolean;
        variable shift_on_this_edge : boolean;
        variable additional_outrun : boolean;
    begin
        if rising_edge(clk) then
            if not is_enabled then
                spi_clk_enable <= false;
                started := false;
                data_pop <= false;
            elsif not started then
                if data_available then
                    data_pop <= true;
                    started := true;
                    data := data_in;
                    edge_count := 0;
                    last_known_spi_clk := spi_clk;
                    if shift_on_rising_edge then
                        start_detected := spi_clk = '1';
                    else
                        start_detected := spi_clk = '0';
                    end if;

                    if start_detected then
                        mosi <= data(7);
                    end if;
                else
                    spi_clk_enable <= false;
                end if;
            else

                if last_known_spi_clk /= spi_clk then
                    edge_count := edge_count + 1;
                end if;

                if last_known_spi_clk = '1' and spi_clk = '0' and not shift_on_rising_edge then
                    shift_on_this_edge := true;
                elsif last_known_spi_clk = '0' and spi_clk = '1' and shift_on_rising_edge then
                    shift_on_this_edge := true;
                else
                    shift_on_this_edge := false;
                end if;

                if shift_on_this_edge then
                    if not start_detected then
                        start_detected := true;
                    else
                        data := data(6 downto 0) & '0';
                    end if;
                    mosi <= data(7);
                end if;

                last_known_spi_clk := spi_clk;
                spi_clk_enable <= true;
                data_pop <= false;

                if edge_count = 16 then
                    started := false;
                end if;
            end if;
        end if;
    end process;
end architecture;
