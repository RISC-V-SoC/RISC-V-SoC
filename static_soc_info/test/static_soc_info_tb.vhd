library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg;

entity static_soc_info_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of static_soc_info_tb is
    constant clk_period : time := 20 ns;
    constant clk_freq_hz : natural := 1 sec / clk_period;
    signal clk : std_logic := '0';
    signal mst2slv : bus_pkg.bus_mst2slv_type := bus_pkg.BUS_MST2SLV_IDLE;
    signal slv2mst : bus_pkg.bus_slv2mst_type;
begin
    clk <= not clk after (clk_period/2);
    process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Read clock speed aligned") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(to_integer(unsigned(slv2mst.readData)), clk_freq_hz);
            elsif run("Read clock speed unaligned") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000002");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(to_integer(unsigned(slv2mst.readData)), clk_freq_hz/65536);
            end if;
        end loop;
        wait until rising_edge(clk) or falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 1 ms);

    static_soc_info : entity src.static_soc_info
    generic map (
        clk_freq_hz => clk_freq_hz
    ) port map (
        clk => clk,
        mst2slv => mst2slv,
        slv2mst => slv2mst
    );
end architecture;
