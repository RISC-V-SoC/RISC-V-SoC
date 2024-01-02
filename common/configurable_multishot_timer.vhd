library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity configurable_multishot_timer is
    generic (
        bit_count   : natural range 1 to natural'high := 31
    );
    port (
        clk : in std_logic;
        reset : in boolean;
        done : out boolean;
        target_value : in unsigned(bit_count downto 0)
    );
end entity;

architecture behavioral of configurable_multishot_timer is
begin

    process(clk)
        variable target_value_buf : unsigned(bit_count downto 0) := (others => '0');
        variable current_value : unsigned(bit_count downto 0) := (others => '0');
    begin
        if rising_edge(clk) then
            done <= false;
            if reset then
                target_value_buf := target_value;
                current_value := to_unsigned(0, current_value'length);
            else
                current_value := current_value + 1;
                if current_value >= target_value_buf then
                    current_value := to_unsigned(0, current_value'length);
                    done <= true;
                end if;
            end if;
        end if;
    end process;
end architecture;
