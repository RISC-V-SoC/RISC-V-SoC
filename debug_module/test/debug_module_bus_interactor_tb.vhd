library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg;
use src.debug_module_pkg;

library tb;
use tb.simulated_bus_memory_pkg;

entity debug_module_bus_interactor_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of debug_module_bus_interactor_tb is
    constant slaveActor : actor_t := new_actor("slave");

    constant clk_period : time := 20 ns;
    constant clk_freq_hz : natural := 1 sec / clk_period;
    signal clk : std_logic := '0';

    signal reset : boolean := false;

    signal address : bus_pkg.bus_address_type := (others => '0');
    signal write_data : bus_pkg.bus_data_type := (others => '0');
    signal read_data : bus_pkg.bus_data_type;
    signal byte_mask : bus_pkg.bus_byte_mask_type := (others => '0');
    signal fault : bus_pkg.bus_fault_type;

    signal do_write : boolean := false;
    signal do_read : boolean := false;

    signal busy : boolean;
    signal transaction_complete : boolean;

    signal mst2slv : bus_pkg.bus_mst2slv_type;
    signal slv2mst : bus_pkg.bus_slv2mst_type := bus_pkg.BUS_SLV2MST_IDLE;
begin
    clk <= not clk after (clk_period/2);
    process
        variable return_data : bus_pkg.bus_data_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Can read") then
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000000", X"11111111", X"f");
                address <= X"00000000";
                byte_mask <= (others => '1');
                do_read <= true;
                wait until rising_edge(clk);
                do_read <= false;
                address <= (others => '-');
                byte_mask <= (others => '-');
                wait until rising_edge(clk) and transaction_complete;
                check(read_data = X"11111111");
                check(fault = bus_pkg.bus_fault_no_fault);
            elsif run("Can read twice") then
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000000", X"11111111", X"f");
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000004", X"22222222", X"f");
                address <= X"00000000";
                byte_mask <= (others => '1');
                do_read <= true;
                wait until rising_edge(clk);
                do_read <= false;
                address <= (others => '-');
                byte_mask <= (others => '-');
                wait until rising_edge(clk) and transaction_complete;
                check(read_data = X"11111111");
                check(fault = bus_pkg.bus_fault_no_fault);
                address <= X"00000004";
                byte_mask <= (others => '1');
                do_read <= true;
                wait until rising_edge(clk);
                do_read <= false;
                address <= (others => '-');
                byte_mask <= (others => '-');
                wait until rising_edge(clk) and transaction_complete;
                check(read_data = X"22222222");
                check(fault = bus_pkg.bus_fault_no_fault);
            elsif run("Reads can error") then
                address <= X"00000002";
                byte_mask <= (others => '1');
                do_read <= true;
                wait until rising_edge(clk);
                do_read <= false;
                address <= (others => '-');
                byte_mask <= (others => '-');
                wait until rising_edge(clk) and transaction_complete;
                check(fault = bus_pkg.bus_fault_unaligned_access);
            elsif run("Busy must be true during read operation") then
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000000", X"11111111", X"f");
                address <= X"00000000";
                byte_mask <= (others => '1');
                do_read <= true;
                wait until rising_edge(clk);
                do_read <= false;
                address <= (others => '-');
                byte_mask <= (others => '-');
                wait until rising_edge(clk);
                while not transaction_complete loop
                    check_true(busy);
                    wait until rising_edge(clk);
                end loop;
                check(read_data = X"11111111");
                check(fault = bus_pkg.bus_fault_no_fault);
            elsif run("Reads respect byte mask") then
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000000", X"11111111", X"f");
                address <= X"00000000";
                byte_mask <= ("1001");
                do_read <= true;
                wait until rising_edge(clk);
                do_read <= false;
                address <= (others => '-');
                byte_mask <= (others => '-');
                wait until rising_edge(clk) and transaction_complete;
                check(read_data(31 downto 24) = X"11");
                check(read_data(7 downto 0) = X"11");
                check(read_data(23 downto 16) /= X"11");
                check(read_data(15 downto 8) /= X"11");
                check(fault = bus_pkg.bus_fault_no_fault);
            elsif run("Can write") then
                address <= X"00000000";
                write_data <= X"67452301";
                byte_mask <= (others => '1');
                do_write <= true;
                wait until rising_edge(clk);
                do_read <= false;
                address <= (others => '-');
                byte_mask <= (others => '-');
                wait until rising_edge(clk) and transaction_complete;
                check(fault = bus_pkg.bus_fault_no_fault);
                simulated_bus_memory_pkg.read_from_address(net, slaveActor, X"00000000", return_data);
                check(return_data = X"67452301");
            elsif run("Writes respect byte mask") then
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000000", X"00000000", X"f");
                address <= X"00000000";
                write_data <= X"67452301";
                byte_mask <= "1001";
                do_write <= true;
                wait until rising_edge(clk);
                do_read <= false;
                address <= (others => '-');
                byte_mask <= (others => '-');
                wait until rising_edge(clk) and transaction_complete;
                check(fault = bus_pkg.bus_fault_no_fault);
                simulated_bus_memory_pkg.read_from_address(net, slaveActor, X"00000000", return_data);
                check(return_data = X"67000001");
            end if;
        end loop;
        wait until rising_edge(clk) or falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 100 us);

    debug_module_bus_interactor : entity src.debug_module_bus_interactor
    port map (
        clk => clk,
        reset => reset,
        address => address,
        write_data => write_data,
        read_data => read_data,
        byte_mask => byte_mask,
        fault => fault,
        do_write => do_write,
        do_read => do_read,
        busy => busy,
        transaction_complete => transaction_complete,
        mst2slv => mst2slv,
        slv2mst => slv2mst
    );

    bus_slave : entity tb.simulated_bus_memory
    generic map (
        depth_log2b => 4,
        allow_unaligned_access => false,
        actor => slaveActor,
        read_delay => 5,
        write_delay => 5
    ) port map (
        clk => clk,
        mst2mem => mst2slv,
        mem2mst => slv2mst
    );
end architecture;
