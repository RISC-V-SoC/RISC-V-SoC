library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library tb;
library src;
use src.triple_23lc1024_pkg.all;

entity triple_23LC1024_cs_control_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of triple_23LC1024_cs_control_tb is
    constant clk_period : time := 20 ns;
    constant spi_cs_setup_ticks : natural := 2;
    constant spi_cs_hold_ticks : natural := 3;

    signal clk : std_logic := '0';
    signal cs_set : std_logic := '1';
    signal cs_state : std_logic;
    signal cs_requested : cs_request_type;
    signal spi_cs_n : std_logic_vector(2 downto 0);
begin
    clk <= not clk after (clk_period/2);

    process
        variable exp_cs_n : std_logic_vector(spi_cs_n'range) := (others => '1');
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Default values are sane") then
                check_equal(cs_state, '1');
                exp_cs_n := (others => '1');
                check_equal(spi_cs_n, exp_cs_n);
            elsif run("Input request_zero gives output 110") then
                cs_requested <= request_zero;
                cs_set <= '0';
                wait until rising_edge(clk) and cs_state = '0';
                exp_cs_n := "110";
                check_equal(spi_cs_n, exp_cs_n);
            elsif run("Device cycles back to 111") then
                cs_requested <= request_one;
                cs_set <= '0';
                wait until rising_edge(clk) and cs_state = '0';
                exp_cs_n := "101";
                check_equal(spi_cs_n, exp_cs_n);
                cs_set <= '1';
                exp_cs_n := "111";
                wait until rising_edge(clk) and cs_state = '1';
                check_equal(spi_cs_n, exp_cs_n);
            end if;
        end loop;
        wait for 2*clk_period;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 100 us);

    mem_pcb : entity tb.triple_M23LC1024
    port map (
        cs_n => spi_cs_n,
        sck => '0'
    );

    cs_control : entity src.triple_23lc1024_cs_control
    generic map (
        spi_cs_setup_ticks => spi_cs_setup_ticks,
        spi_cs_hold_ticks => spi_cs_hold_ticks
    ) port map (
        clk => clk,
        cs_set => cs_set,
        cs_state => cs_state,
        cs_requested => cs_requested,
        spi_cs_n => spi_cs_n
    );
end architecture;
