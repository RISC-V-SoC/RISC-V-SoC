library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg.all;

library tb;
use tb.bus_tb_pkg.all;

entity bus_arbiter_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of bus_arbiter_tb is
    constant clk_period : time := 20 ns;

    signal clk : std_logic := '0';
    signal mst2arbiter : bus_mst2slv_array(0 to 2) := (others => (BUS_MST2SLV_IDLE));
    signal arbiter2mst : bus_slv2mst_array(0 to 2);
    signal arbiter2slv : bus_mst2slv_type;
    signal slv2arbiter : bus_slv2mst_type;
begin

    clk <= not clk after (clk_period/2);

    main : process
        variable actualAddress : std_logic_vector(bus_address_type'range);
        variable nextAddress : std_logic_vector(bus_address_type'range);
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Arbiter selects slave 2") then
                actualAddress := std_logic_vector(to_unsigned(4, bus_address_type'length));
                mst2arbiter(2) <= bus_mst2slv_read(address => actualAddress);
                wait until arbiter2slv.readReady = '1';
                check_equal(actualAddress, arbiter2slv.address);
            elsif run ("Arbiter respects order") then
                actualAddress := std_logic_vector(to_unsigned(4, bus_address_type'length));
                nextAddress := std_logic_vector(to_unsigned(8, bus_address_type'length));
                mst2arbiter(1) <= bus_mst2slv_read(address => actualAddress);
                wait until arbiter2slv.readReady = '1' and rising_edge(clk);
                mst2arbiter(1) <= BUS_MST2SLV_IDLE;
                wait until rising_edge(clk);
                actualAddress := std_logic_vector(to_unsigned(12, bus_address_type'length));
                mst2arbiter(2) <= bus_mst2slv_read(address => actualAddress);
                mst2arbiter(0) <= bus_mst2slv_read(address => nextAddress);
                wait until arbiter2slv.readReady = '1' and rising_edge(clk);
                check_equal(actualAddress, arbiter2slv.address);
            elsif run ("Arbiter respects burst") then
                actualAddress := std_logic_vector(to_unsigned(4, bus_address_type'length));
                nextAddress := std_logic_vector(to_unsigned(8, bus_address_type'length));
                mst2arbiter(0) <= bus_mst2slv_read(address => actualAddress, burst => '1');
                mst2arbiter(1) <= bus_mst2slv_read(address => nextAddress);
                wait until arbiter2slv.readReady = '1' and rising_edge(clk);
                mst2arbiter(0).readReady <= '0';
                check_equal(actualAddress, arbiter2slv.address);
                wait until arbiter2slv.readReady = '0' and rising_edge(clk);
                check_equal(actualAddress, arbiter2slv.address);
            elsif run ("Arbiter returns data") then
                actualAddress := std_logic_vector(to_unsigned(4, bus_address_type'length));
                mst2arbiter(2) <= bus_mst2slv_read(address => actualAddress);
                wait until arbiter2slv.readReady = '1';
                check_equal(actualAddress, arbiter2slv.address);
                slv2arbiter.valid <= true;
                slv2arbiter.readData <= X"00112233";
                wait until rising_edge(clk);
                check_equal(slv2arbiter.readData, arbiter2mst(2).readData);
            elsif run("Arbiter selects slave 0 after slave 2") then
                actualAddress := std_logic_vector(to_unsigned(4, bus_address_type'length));
                mst2arbiter(2) <= bus_mst2slv_read(address => actualAddress);
                wait until rising_edge(clk) and arbiter2slv.readReady = '1';
                slv2arbiter.valid <= true;
                actualAddress := std_logic_vector(to_unsigned(0, bus_address_type'length));
                mst2arbiter(0) <= bus_mst2slv_read(address => actualAddress);
                wait until rising_edge(clk);
                mst2arbiter(2) <= BUS_MST2SLV_IDLE;
                slv2arbiter <= BUS_SLV2MST_IDLE;
                wait until rising_edge(clk) and arbiter2slv.readReady = '1';
                check_equal(actualAddress, arbiter2slv.address);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 us);

    arbiter : entity src.bus_arbiter
    generic map (
        masterCount => 3
    ) port map (
        clk => clk,
        mst2arbiter => mst2arbiter,
        arbiter2mst => arbiter2mst,
        arbiter2slv => arbiter2slv,
        slv2arbiter => slv2arbiter
    );
end architecture;
