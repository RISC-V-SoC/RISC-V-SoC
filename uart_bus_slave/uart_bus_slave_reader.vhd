library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_bus_slave_reader is
    port (
        clk : in std_logic;
        reset : in boolean;

        half_baud_clk_ticks : in unsigned(31 downto 0);
        
        rx : in std_logic;
        data_out : out std_logic_vector(7 downto 0);
        data_ready : out boolean
    );
end entity;

architecture behavioral of uart_bus_slave_reader is
    signal timer_reset : boolean;
    signal timer_done : boolean;
begin
    process(clk)
        variable process_counter : natural range 0 to 19 := 0;
        variable has_read : boolean := false;
        variable data_out_buf : std_logic_vector(7 downto 0) := (others => '0');
        variable timer_reset_buf : boolean := true;
    begin
        if rising_edge(clk) then
            if reset then
                process_counter := 0;
                has_read := false;
                timer_reset_buf := true;
                data_ready <= false;
            else
                if process_counter = 0 then
                    data_ready <= false;
                    if rx = '0' then
                        timer_reset_buf := false;
                    end if;
                end if;

                if timer_done then
                    process_counter := process_counter + 1;
                end if;

                if process_counter >= 3 and process_counter <= 18 then
                    if process_counter mod 2 = 1 then
                        if not has_read then
                            data_out_buf := rx & data_out_buf(7 downto 1);
                            has_read := true;
                        end if;
                    else
                        has_read := false;
                    end if;
                end if;

                if process_counter = 19 then
                    timer_reset_buf := true;
                    process_counter := 0;
                    if rx = '1' then
                        data_ready <= true;
                    end if;
                end if;
            end if;
        end if;
        data_out <= data_out_buf;
        timer_reset <= timer_reset_buf;
    end process;
    
    configurable_timer : entity work.configurable_multishot_timer
    port map (
        clk => clk,
        reset => timer_reset,
        done => timer_done,
        target_value => half_baud_clk_ticks
    );
end architecture;
