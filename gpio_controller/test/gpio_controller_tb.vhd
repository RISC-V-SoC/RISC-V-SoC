library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg;

entity gpio_controller_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of gpio_controller_tb is
    constant clk_period : time := 20 ns;
    constant gpio_count : natural := 5;
    signal clk : std_logic := '0';
    signal reset : boolean := false;
    signal gpio : std_logic_vector(gpio_count - 1 downto 0);
    signal mst2slv : bus_pkg.bus_mst2slv_type := bus_pkg.BUS_MST2SLV_IDLE;
    signal slv2mst : bus_pkg.bus_slv2mst_type;
begin
    clk <= not clk after (clk_period/2);
    process
        variable write_data : bus_pkg.bus_data_type := (others => '0');
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            gpio <= (others => 'Z');
            if run("By default, all gpio is input") then
                for i in 0 to gpio_count - 1 loop
                    mst2slv <= bus_pkg.bus_mst2slv_read(std_logic_vector(to_unsigned(i, bus_pkg.bus_address_type'length)), "0001");
                    wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                    check_equal(slv2mst.readData(7 downto 0), std_logic_vector'(X"00"));
                end loop;
            elsif run("Test config write then read") then
                write_data(1 downto 0) := "01";
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000004", write_data, "0001");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000004");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(1 downto 0), std_logic_vector'("01"));
            elsif run("Byte mask works") then
                write_data(1 downto 0) := "01";
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000004", write_data, "1110");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000004");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(1 downto 0), std_logic_vector'("00"));
            elsif run("Can set output to 1") then
                write_data(1 downto 0) := "01";
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000000", write_data, "0001");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000005", write_data, "0001");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                check_equal(gpio(0), '1');
            elsif run("Inputs can be read") then
                write_data(1 downto 0) := "00";
                gpio(0) <= '1';
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000000", write_data, "0001");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                write_data(1 downto 0) := "01";
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000005");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(0), '1');
            elsif run("Reset works") then
                write_data(1 downto 0) := "01";
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000000", write_data, "0001");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000005", write_data, "0001");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                reset <= true;
                wait for clk_period;
                reset <= false;
                for i in 0 to gpio_count - 1 loop
                    mst2slv <= bus_pkg.bus_mst2slv_read(std_logic_vector(to_unsigned(i, bus_pkg.bus_address_type'length)), "0001");
                    wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                    check_equal(slv2mst.readData(7 downto 0), std_logic_vector'(X"00"));
                end loop;
            end if;
        end loop;
        wait until rising_edge(clk) or falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 1 ms);

    gpio_controller : entity src.gpio_controller
    generic map (
        gpio_count => gpio_count
    ) port map (
        clk => clk,
        reset => reset,
        gpio => gpio,
        mst2slv => mst2slv,
        slv2mst => slv2mst
    );
end architecture;
