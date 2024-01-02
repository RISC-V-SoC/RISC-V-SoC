library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.triple_23lc1024_pkg.all;

entity triple_23lc1024_cs_control is
    generic (
        spi_cs_setup_ticks : natural;
        spi_cs_hold_ticks : natural
    );
    port (
        clk : in std_logic;

        cs_set : in std_logic;
        cs_state : out std_logic;

        cs_requested : in cs_request_type;
        spi_cs_n : out std_logic_vector(2 downto 0)
    );
end triple_23lc1024_cs_control;

architecture behavioral of triple_23lc1024_cs_control is

    signal setup_timer_rst : std_logic := '1';
    signal setup_timer_done : std_logic;

    signal hold_timer_rst : std_logic := '1';
    signal hold_timer_done : std_logic;
begin

    process(clk)
        variable cs_state_internal : std_logic := '1';
        variable spi_cs_n_internal : std_logic_vector(spi_cs_n'range) := (others => '1');
        variable spi_cs_n_decoded : std_logic_vector(spi_cs_n'range) := (others => '1');
    begin
        if rising_edge(clk) then
            case cs_requested is
                when request_zero =>
                    spi_cs_n_decoded := "110";
                when request_one =>
                    spi_cs_n_decoded := "101";
                when request_two =>
                    spi_cs_n_decoded := "011";
                when others =>
                    spi_cs_n_decoded := "111";
            end case;

            setup_timer_rst <= '1';
            hold_timer_rst <= '1';
            if cs_set = '0' and cs_state_internal = '1' then
                spi_cs_n_internal := spi_cs_n_decoded;
                setup_timer_rst <= '0';
                if setup_timer_done = '1' then
                    cs_state_internal := '0';
                end if;
            elsif cs_set = '1' and cs_state_internal = '0' then
                hold_timer_rst <= '0';
                if hold_timer_done = '1' then
                    cs_state_internal := '1';
                    spi_cs_n_internal := (others => '1');
                end if;
            end if;
        end if;
        cs_state <= cs_state_internal;
        spi_cs_n <= spi_cs_n_internal;
    end process;

    setup_timer : entity work.simple_multishot_timer
    generic map (
        match_val => spi_cs_setup_ticks
    )
    port map (
        clk => clk,
        rst => setup_timer_rst,
        done => setup_timer_done
    );

    hold_timer : entity work.simple_multishot_timer
    generic map (
        match_val => spi_cs_hold_ticks
    )
    port map (
        clk => clk,
        rst => hold_timer_rst,
        done => hold_timer_done
    );
end behavioral;
