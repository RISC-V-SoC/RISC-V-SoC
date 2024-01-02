library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_bus_slave_writer is
    port (
        clk : in std_logic;
        reset : in boolean;

        half_baud_clk_ticks : in unsigned(31 downto 0);
        
        tx : out std_logic;
        data_in : in std_logic_vector(7 downto 0);
        data_available : in boolean;
        data_pop : out boolean
    );
end entity;

architecture behavioral of uart_bus_slave_writer is
    signal timer_reset : boolean;
    signal timer_done : boolean;
begin
    process(clk)
        variable process_counter : natural range 0 to 20 := 0;
        variable has_shifted : boolean := false;
        variable data_copied : boolean := false;
        variable data_in_buf : std_logic_vector(7 downto 0) := (others => '0');
        variable timer_reset_buf : boolean := true;
        variable tx_buf : std_logic := '1';
    begin
        if rising_edge(clk) then
            if reset then
                process_counter := 0;
                has_shifted := false;
                data_copied := false;
                timer_reset_buf := true;
                data_pop <= false;
                tx_buf := '1';
            else
                data_pop <= false;
                if process_counter = 0 then
                    if not data_copied then
                        tx_buf := '1';
                        if data_available then
                            data_in_buf := data_in;
                            data_pop <= true;
                            data_copied := true;
                            timer_reset_buf := false;
                            tx_buf := '0';
                        end if;
                    end if;
                end if;

                if timer_done then
                    process_counter := process_counter + 1;
                end if;

                if process_counter >= 2 and process_counter < 18 then
                    tx_buf := data_in_buf(0);
                end if;


                if process_counter >= 4 and process_counter < 18 then
                    if process_counter mod 2 = 0 then
                        if not has_shifted then
                            data_in_buf := '0' & data_in_buf(7 downto 1);
                            has_shifted := true;
                        end if;
                    else
                        has_shifted := false;
                    end if;
                end if;

                if process_counter >= 18 then
                    tx_buf := '1';
                end if;

                if process_counter = 20 then
                    timer_reset_buf := true;
                    process_counter := 0;
                    data_copied := false;
                end if;
            end if;
        end if;
        timer_reset <= timer_reset_buf;
        tx <= tx_buf;
    end process;
    
    configurable_timer : entity work.configurable_multishot_timer
    port map (
        clk => clk,
        reset => timer_reset,
        done => timer_done,
        target_value => half_baud_clk_ticks
    );
end architecture;
