library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.math_real.ALL;
use IEEE.NUMERIC_STD.ALL;

entity simple_multishot_timer is
    generic (
        match_val   : natural range 1 to natural'high;
        reset_val   : natural range 0 to match_val := 0
    );
    port (
        clk         : in STD_LOGIC;
        rst         : in STD_LOGIC;
        done        : out STD_LOGIC
    );
end simple_multishot_timer;

architecture behavioral of simple_multishot_timer is
begin
    process (clk)
        variable timer_value : natural range 0 to match_val := 0;
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                    timer_value := reset_val;
                    done <= '0';
            elsif timer_value >= match_val then
                    done <= '1';
                    timer_value := 1;
            else
                timer_value := timer_value + 1;
                done <= '0';
            end if;
        end if;
    end process;
end behavioral;
