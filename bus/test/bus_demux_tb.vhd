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

entity bus_demux_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of bus_demux_tb is

    constant clk_period : time := 20 ns;

    constant firstRange     :   addr_range_and_mapping_type := address_range_and_map(
        low => std_logic_vector(to_unsigned(0, bus_address_type'length)),
        high => std_logic_vector(to_unsigned(15, bus_address_type'length))
    );

    constant secondRangeMap : addrMapping_type := bus_map_constant(bus_address_type'high - 4, '0') & bus_map_range(4, 0);

    constant secondRange    :   addr_range_and_mapping_type := address_range_and_map(
        low => std_logic_vector(to_unsigned(32, bus_address_type'length)),
        high => std_logic_vector(to_unsigned(63, bus_address_type'length)),
        mapping => secondRangeMap
    );

    signal demux2firstSlave : bus_mst2slv_type := BUS_MST2SLV_IDLE;
    signal demux2secondSlave : bus_mst2slv_type := BUS_MST2SLV_IDLE;
    signal firstSlave2demux : bus_slv2mst_type := BUS_SLV2MST_IDLE;
    signal secondSlave2demux : bus_slv2mst_type := BUS_SLV2MST_IDLE;

    signal demux2master : bus_slv2mst_type := BUS_SLV2MST_IDLE;
    signal master2demux : bus_mst2slv_type := BUS_MST2SLV_IDLE;
    signal clk : std_logic := '0';

    signal helper_master : bus_mst2slv_type := BUS_MST2SLV_IDLE;

    function busMasterIsIdle(master: bus_mst2slv_type) return boolean is
    begin
        return master.readReady = '0' and master.writeReady = '0' and master.burst = '0';
    end function;

begin

    clk <= not clk after (clk_period/2);

    main : process
        variable actualAddress : std_logic_vector(bus_address_type'range);
        variable expectedAddress : std_logic_vector(bus_address_type'range);
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Hit first slave without remapping") then
                actualAddress := std_logic_vector(to_unsigned(4, bus_address_type'length));
                expectedAddress := actualAddress;
                master2demux <= bus_mst2slv_read(address => actualAddress);
                wait until rising_edge(clk);
                check(demux2firstSlave.readReady = '1');
                check_equal(demux2firstSlave.address, expectedAddress);
            elsif run("Second slave is idle if first slave is addressed") then
                actualAddress := std_logic_vector(to_unsigned(4, bus_address_type'length));
                expectedAddress := actualAddress;
                master2demux <= bus_mst2slv_read(address => actualAddress);
                wait until rising_edge(clk);
                check(busMasterIsIdle(demux2secondSlave));
            elsif run("Hit second slave with remapping") then
                actualAddress := std_logic_vector(to_unsigned(36, bus_address_type'length));
                expectedAddress := std_logic_vector(to_unsigned(4, bus_address_type'length));
                master2demux <= bus_mst2slv_read(address => actualAddress);
                wait until rising_edge(clk);
                check(demux2secondSlave.readReady = '1');
                check_equal(demux2secondSlave.address, expectedAddress);
            elsif run("Out of range results in correct error") then
                actualAddress := std_logic_vector(to_unsigned(64, bus_address_type'length));
                master2demux <= bus_mst2slv_read(address => actualAddress);
                wait until rising_edge(clk);
                check(demux2master.fault = '1');
                check(demux2master.faultData = bus_fault_address_out_of_range);
            elsif run("No slave is addressed on out of range error") then
                actualAddress := std_logic_vector(to_unsigned(64, bus_address_type'length));
                master2demux <= bus_mst2slv_read(address => actualAddress);
                wait until rising_edge(clk);
                check(busMasterIsIdle(demux2firstSlave));
                check(busMasterIsIdle(demux2secondSlave));
            elsif run("Answer from correct slave is passed on") then
                actualAddress := std_logic_vector(to_unsigned(4, bus_address_type'length));
                master2demux <= bus_mst2slv_read(address => actualAddress);
                secondSlave2demux.valid <= true;
                secondSlave2demux.fault <= '1';
                secondSlave2demux.readData <= X"000000FF";
                secondSlave2demux.faultData <= bus_fault_address_out_of_range;

                firstSlave2demux.valid <= true;
                firstSlave2demux.readData <= X"000000AA";
                firstSlave2demux.faultData <= bus_fault_no_fault;
                wait until rising_edge(clk);
                check(demux2master.valid);
                check(demux2master.fault = '0');
                check(demux2master.readData = X"000000AA");
                check(demux2master.faultData = bus_fault_no_fault);
            elsif run("Burst causes selection") then
                actualAddress := std_logic_vector(to_unsigned(4, bus_address_type'length));
                expectedAddress := actualAddress;
                master2demux <= bus_mst2slv_read(address => actualAddress, burst => '1');
                master2demux.readReady <= '0';
                wait until rising_edge(clk);
                check(demux2firstSlave.burst = '1');
                check_equal(demux2firstSlave.address, expectedAddress);
            elsif run("An idle master selects nothing") then
                actualAddress := std_logic_vector(to_unsigned(4, bus_address_type'length));
                expectedAddress := (others => 'X');
                master2demux.address <= actualAddress;
                wait until rising_edge(clk);
                check_equal(demux2firstSlave.address, expectedAddress);
                check_equal(demux2secondSlave.address, expectedAddress);
                check(busMasterIsIdle(demux2firstSlave));
                check(busMasterIsIdle(demux2secondSlave));
            end if;
        end loop;
        wait until rising_edge(clk) or falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    demux : entity src.bus_demux
    generic map (
        ADDRESS_MAP(0) => firstRange,
        ADDRESS_MAP(1) => secondRange
    )
    port map (
        mst2demux => master2demux,
        demux2mst => demux2master,
        demux2slv(0) => demux2firstSlave,
        demux2slv(1) => demux2secondSlave,
        slv2demux(0) => firstSlave2demux,
        slv2demux(1) => secondSlave2demux
    );
end architecture;
