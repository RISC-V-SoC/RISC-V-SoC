library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg;

entity spi_master_bus_slave_slave_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of spi_master_bus_slave_slave_tb is
    constant clk_period : time := 20 ns;
    signal clk : std_logic := '0';
    signal miso : std_logic;
    signal spi_clk : std_logic := '0';
    signal is_enabled : boolean := false;
    signal shift_on_rising_edge : boolean := false;
    signal data_out : std_logic_vector(7 downto 0);
    signal data_ready : boolean;
    signal data_clocked : std_logic_vector(7 downto 0);
begin
    clk <= not clk after (clk_period/2);
    process
        variable data : std_logic_vector(7 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Byte transaction with CPOL = CPHA = 0") then
                data := "10101010";
                is_enabled <= true;
                shift_on_rising_edge <= false;
                spi_clk <= '0';
                for i in 0 to 7 loop
                    miso <= data(7 - i);
                    wait for 5*clk_period;
                    spi_clk <= '1';
                    wait for 5*clk_period;
                    spi_clk <= '0';
                end loop;
                check_equal(data_clocked, data);
            elsif run("Two byte transaction with CPOL = CPHA = 0") then
                data := "10101010";
                is_enabled <= true;
                shift_on_rising_edge <= false;
                spi_clk <= '0';
                for i in 0 to 7 loop
                    miso <= data(7 - i);
                    wait for 5*clk_period;
                    spi_clk <= '1';
                    wait for 5*clk_period;
                    spi_clk <= '0';
                end loop;
                data := "11110000";
                for i in 0 to 7 loop
                    miso <= data(7 - i);
                    wait for 5*clk_period;
                    spi_clk <= '1';
                    wait for 5*clk_period;
                    spi_clk <= '0';
                end loop;
                check_equal(data_clocked, data);
            elsif run("Byte transaction with CPOL = 1, CPHA = 0") then
                data := "10101010";
                is_enabled <= true;
                shift_on_rising_edge <= false;
                spi_clk <= '1';
                for i in 0 to 7 loop
                    wait for 5*clk_period;
                    spi_clk <= '0';
                    miso <= data(7 - i);
                    wait for 5*clk_period;
                    spi_clk <= '1';
                end loop;
                wait for 5*clk_period;
                check_equal(data_clocked, data);
            elsif run("Handles polarity switch") then
                data := "10101010";
                is_enabled <= true;
                shift_on_rising_edge <= false;
                spi_clk <= '0';
                for i in 0 to 7 loop
                    miso <= data(7 - i);
                    wait for 5*clk_period;
                    spi_clk <= '1';
                    wait for 5*clk_period;
                    spi_clk <= '0';
                end loop;
                wait for 5*clk_period;
                data := "11110000";
                is_enabled <= false;
                spi_clk <= '1';
                wait until rising_edge(clk);
                is_enabled <= true;
                for i in 0 to 7 loop
                    wait for 5*clk_period;
                    spi_clk <= '0';
                    miso <= data(7 - i);
                    wait for 5*clk_period;
                    spi_clk <= '1';
                end loop;
                wait for 5*clk_period;
                check_equal(data_clocked, data);
            elsif run("Interrupting a transaction then starting a new one works") then
                data := "10101010";
                is_enabled <= true;
                shift_on_rising_edge <= false;
                spi_clk <= '0';
                for i in 0 to 4 loop
                    miso <= data(7 - i);
                    wait for 5*clk_period;
                    spi_clk <= '1';
                    wait for 5*clk_period;
                    spi_clk <= '0';
                end loop;
                wait for 5*clk_period;
                data := "11110000";
                is_enabled <= false;
                spi_clk <= '1';
                wait until rising_edge(clk);
                is_enabled <= true;
                for i in 0 to 7 loop
                    wait for 5*clk_period;
                    spi_clk <= '0';
                    miso <= data(7 - i);
                    wait for 5*clk_period;
                    spi_clk <= '1';
                end loop;
                wait for 5*clk_period;
                check_equal(data_clocked, data);
            elsif run("Byte transaction with CPOL = 0, CPHA = 1") then
                data := "11101001";
                is_enabled <= true;
                shift_on_rising_edge <= true;
                spi_clk <= '0';
                for i in 0 to 7 loop
                    wait for 5*clk_period;
                    spi_clk <= '1';
                    wait for 2*clk_period;
                    miso <= data(7 - i);
                    wait for 3*clk_period;
                    spi_clk <= '0';
                end loop;
                wait for 5*clk_period;
                check_equal(data_clocked, data);
            end if;
        end loop;
        wait until rising_edge(clk) or falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    process(clk)
    begin
        if rising_edge(clk) and data_ready then
            data_clocked <= data_out;
        end if;
    end process;

    test_runner_watchdog(runner, 100 us);

    spi_master_bus_slave_slave : entity src.spi_master_bus_slave_slave
    port map (
        clk => clk,
        miso => miso,
        spi_clk => spi_clk,
        is_enabled => is_enabled,
        shift_on_rising_edge => shift_on_rising_edge,
        data_out => data_out,
        data_ready => data_ready
    );
end architecture;
