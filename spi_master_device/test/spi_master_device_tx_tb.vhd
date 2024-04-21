library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg;

entity spi_master_device_tx_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of spi_master_device_tx_tb is
    constant clk_period : time := 20 ns;
    signal clk : std_logic := '0';
    signal mosi : std_logic;
    signal spi_clk : std_logic := '0';
    signal is_enabled : boolean := true;
    signal shift_on_rising_edge : boolean := false;
    signal spi_clk_enable : boolean;
    signal data_to_master : std_logic_vector(7 downto 0) := (others => '0');
    signal data_available : boolean := false;
    signal data_pop : boolean;
begin
    clk <= not clk after (clk_period/2);
    process
        variable address : bus_pkg.bus_address_type;
        variable data : bus_pkg.bus_data_type;
        variable byte_mask : bus_pkg.bus_byte_mask_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Pops data when available") then
                data_available <= true;
                wait until rising_edge(clk) and data_pop;
            elsif run("Does not pop when no data available") then
                data_available <= false;
                wait until rising_edge(clk);
                check(not data_pop);
                wait until rising_edge(clk);
                check(not data_pop);
            elsif run("Pop is disabled after one cycle") then
                data_available <= true;
                wait until rising_edge(clk) and data_pop;
                wait until rising_edge(clk);
                check(not data_pop);
            elsif run("When not enabled, does not pop when data available") then
                is_enabled <= false;
                data_available <= true;
                wait until rising_edge(clk);
                check(not data_pop);
                wait until rising_edge(clk);
                check(not data_pop);
            elsif run("Enables clock when starting") then
                data_available <= true;
                wait until rising_edge(clk) and data_pop;
                wait until rising_edge(clk) and spi_clk_enable;
            elsif run("Byte transaction with CPOL = CPHA = 0") then
                data_to_master <= "10101010";
                data_available <= true;
                shift_on_rising_edge <= false;
                spi_clk <= '0';
                wait until rising_edge(clk) and data_pop;
                wait until rising_edge(clk) and spi_clk_enable;
                for i in 0 to 7 loop
                    wait for 4*clk_period;
                    check_equal(mosi, data_to_master(7-i));
                    wait for 1*clk_period;
                    spi_clk <= '1';
                    wait for 5*clk_period;
                    spi_clk <= '0';
                end loop;
            elsif run("Byte transaction with CPOL = 0, CPHA = 1") then
                data_to_master <= "10101010";
                data_available <= true;
                shift_on_rising_edge <= true;
                spi_clk <= '0';
                wait until rising_edge(clk) and data_pop;
                wait until rising_edge(clk) and spi_clk_enable;
                wait for 5*clk_period;
                for i in 0 to 7 loop
                    spi_clk <= '1';
                    wait for 5*clk_period;
                    spi_clk <= '0';
                    wait for 4*clk_period;
                    check_equal(mosi, data_to_master(7-i));
                    wait for clk_period;
                end loop;
            elsif run("Byte transaction with CPOL = 1, CPHA = 0") then
                data_to_master <= "10101010";
                data_available <= true;
                shift_on_rising_edge <= false;
                spi_clk <= '1';
                wait until rising_edge(clk) and data_pop;
                wait until rising_edge(clk) and spi_clk_enable;
                wait for 5*clk_period;
                for i in 0 to 7 loop
                    spi_clk <= '0';
                    wait for 5*clk_period;
                    spi_clk <= '1';
                    wait for 4*clk_period;
                    check_equal(mosi, data_to_master(7-i));
                    wait for clk_period;
                end loop;
            elsif run("Byte transaction with CPOL = CPHA = 1") then
                data_to_master <= "10101010";
                data_available <= true;
                shift_on_rising_edge <= true;
                spi_clk <= '1';
                wait until rising_edge(clk) and data_pop;
                wait until rising_edge(clk) and spi_clk_enable;
                for i in 0 to 7 loop
                    wait for 4*clk_period;
                    check_equal(mosi, data_to_master(7-i));
                    wait for 1*clk_period;
                    spi_clk <= '0';
                    wait for 5*clk_period;
                    spi_clk <= '1';
                end loop;
            elsif run("CPOL = CPHA = 0 transaction finishes") then
                data_to_master <= "10101010";
                data_available <= true;
                spi_clk <= '0';
                wait until rising_edge(clk) and data_pop;
                data_available <= false;
                wait until rising_edge(clk) and spi_clk_enable;
                for i in 0 to 7 loop
                    wait for 5*clk_period;
                    spi_clk <= '1';
                    wait for 5*clk_period;
                    spi_clk <= '0';
                end loop;
                wait for 9*clk_period;
                check(not spi_clk_enable);
            elsif run("Disabling transaction midway trough disables clock") then
                data_to_master <= "10101010";
                data_available <= true;
                shift_on_rising_edge <= true;
                spi_clk <= '0';
                wait until rising_edge(clk) and data_pop;
                wait until rising_edge(clk) and spi_clk_enable;
                for i in 0 to 3 loop
                    wait for 5*clk_period;
                    spi_clk <= '1';
                    wait for 5*clk_period;
                    spi_clk <= '0';
                end loop;
                is_enabled <= false;
                wait until rising_edge(clk) and not spi_clk_enable;
            elsif run("Interrupting transaction then starting a new one works") then
                data_to_master <= "11110000";
                data_available <= true;
                shift_on_rising_edge <= true;
                spi_clk <= '0';
                wait until rising_edge(clk) and data_pop;
                wait until rising_edge(clk) and spi_clk_enable;
                for i in 0 to 3 loop
                    wait for 5*clk_period;
                    spi_clk <= '1';
                    wait for 5*clk_period;
                    spi_clk <= '0';
                end loop;
                is_enabled <= false;
                wait until rising_edge(clk) and not spi_clk_enable;
                is_enabled <= true;
                wait until rising_edge(clk) and data_pop;
                wait until rising_edge(clk) and spi_clk_enable;
                for i in 0 to 7 loop
                    spi_clk <= '1';
                    wait for 5*clk_period;
                    spi_clk <= '0';
                    wait for 4*clk_period;
                    check_equal(mosi, data_to_master(7-i));
                    wait for clk_period;
                end loop;
            end if;
        end loop;
        wait until rising_edge(clk) or falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 100 us);

    spi_master_device_tx : entity src.spi_master_device_tx
    port map (
        clk => clk,
        mosi => mosi,
        spi_clk => spi_clk,
        is_enabled => is_enabled,
        shift_on_rising_edge => shift_on_rising_edge,
        spi_clk_enable => spi_clk_enable,
        data_in => data_to_master,
        data_available => data_available,
        data_pop => data_pop
    );
end architecture;
