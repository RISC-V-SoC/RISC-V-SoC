library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg;

entity timer_register_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of timer_register_tb is
    constant clk_period : time := 20 ns;
    constant clk_freq_hz : natural := 1 sec / clk_period;
    signal clk : std_logic := '0';
    signal reset : boolean := false;
    signal timer_interrupt_pending : boolean;
    signal mst2slv : bus_pkg.bus_mst2slv_type := bus_pkg.BUS_MST2SLV_IDLE;
    signal slv2mst : bus_pkg.bus_slv2mst_type;
begin
    clk <= not clk after (clk_period/2);
    process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("After a reset, both mtime and mtimecmp are 0") then
                reset <= true;
                wait until falling_edge(clk);
                reset <= false;
                wait until falling_edge(clk);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(or_reduce(slv2mst.readData), '0');
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000004");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(or_reduce(slv2mst.readData), '0');
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000008");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(or_reduce(slv2mst.readData), '0');
                mst2slv <= bus_pkg.bus_mst2slv_read(X"0000000c");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(or_reduce(slv2mst.readData), '0');
            elsif run("After a reset, timer_interrupt_pending is true") then
                reset <= true;
                wait until falling_edge(clk);
                reset <= false;
                wait until falling_edge(clk);
                check_true(timer_interrupt_pending);
            elsif run("Test set and read mtime") then
                mst2slv <= bus_pkg.bus_mst2slv_write(address => X"00000000", write_data => X"0f0f0f0f");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check(slv2mst.readData = X"0f0f0f0f");
            elsif run("Writes respect byte masks") then
                mst2slv <= bus_pkg.bus_mst2slv_write(address => X"00000000", write_data => X"0f0f0f0f", byte_mask => "0101");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check(slv2mst.readData = X"000f000f");
            elsif run("Unaligned writes work as expected") then
                mst2slv <= bus_pkg.bus_mst2slv_write(address => X"00000006", write_data => X"cfcfcfcf");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000004");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check(slv2mst.readData = X"cfcf0000");
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000008");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check(slv2mst.readData = X"0000cfcf");
            elsif run("If mtimecmp is bigger than mtime, timer_interrupt_pending is false") then
                mst2slv <= bus_pkg.bus_mst2slv_write(address => X"00000008", write_data => X"0f0f0f0f");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                check_false(timer_interrupt_pending);
            elsif run("Every microsecond, mtime increases") then
                reset <= true;
                wait until falling_edge(clk);
                reset <= false;
                wait until falling_edge(clk);
                wait for 3.5 us;
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check(slv2mst.readData = X"00000003");
            elsif run("If mtime overflows, mtimecmp is unaffected") then
                mst2slv <= bus_pkg.bus_mst2slv_write(address => X"00000000", write_data => X"ffffffff");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_write(address => X"00000004", write_data => X"ffffffff");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                wait for 1.5 us;
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(or_reduce(slv2mst.readData), '0');
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000004");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(or_reduce(slv2mst.readData), '0');
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000008");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(or_reduce(slv2mst.readData), '0');
                mst2slv <= bus_pkg.bus_mst2slv_read(X"0000000c");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(or_reduce(slv2mst.readData), '0');
            end if;
        end loop;
        wait until rising_edge(clk) or falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 100 us);

    timer_register : entity src.timer_register
    generic map (
        clk_period => clk_period,
        timer_period => 1 us
    ) port map (
        clk => clk,
        reset => reset,
        timer_interrupt_pending => timer_interrupt_pending,
        mst2slv => mst2slv,
        slv2mst => slv2mst
    );
end architecture;
