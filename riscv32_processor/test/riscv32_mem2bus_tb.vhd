library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library tb;
use tb.simulated_bus_memory_pkg;

library src;
use src.bus_pkg.all;
use src.riscv32_pkg.all;

entity riscv32_mem2bus_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_mem2bus_tb is

    constant cache_range_start : natural := 16#400#;
    constant cache_range_end : natural := 16#800# - 1;
    constant range_to_cache : addr_range_type := (
            low => std_logic_vector(to_unsigned(cache_range_start, bus_address_type'length)),
            high => std_logic_vector(to_unsigned(cache_range_end, bus_address_type'length))
        );

    constant clk_period : time := 20 ns;
    constant slaveActor : actor_t := new_actor("slave");

    signal forbidBusInteraction : boolean := false;
    signal flushCache : boolean := false;

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';

    signal mst2slv : bus_mst2slv_type;
    signal slv2mst : bus_slv2mst_type;

    signal hasFault : boolean;
    signal faultData : bus_fault_type;

    signal address : riscv32_address_type := (others => '0');
    signal byteMask : riscv32_byte_mask_type := (others => '1');
    signal dataIn : riscv32_data_type := (others => '0');
    signal dataOut : riscv32_data_type;
    signal doWrite : boolean := false;
    signal doRead : boolean := false;

    signal stall : boolean;
begin

    clk <= not clk after (clk_period/2);

    main : process
        variable expectedWriteData : riscv32_data_type;
        variable expectedWriteAddress : riscv32_address_type;
        variable writeAddress : bus_address_type;
        variable writeData : bus_data_type;
        variable memReadData : bus_data_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Requesting read stalls before next rising_edge") then
                doRead <= true;
                wait until rising_edge(clk);
                check(stall);
            elsif run("Requesting read stalls until data is ready") then
                writeAddress := X"00000004";
                writeData := X"01234567";
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => slaveActor,
                    addr => writeAddress,
                    mask => (others => '1'),
                    data => writeData);
                doRead <= true;
                address <= writeAddress;
                wait until rising_edge(clk) and not stall;
                check_equal(dataOut, writeData);
            elsif run("Single write does lead to stall") then
                doWrite <= true;
                wait until rising_edge(clk);
                check(stall);
            elsif run("Requesting write stalls until transaction is finished") then
                expectedWriteData := X"AABBCCDD";
                expectedWriteAddress := X"00000008";
                dataIn <= expectedWriteData;
                address <= expectedWriteAddress;
                doWrite <= true;
                wait until rising_edge(clk) and not stall;
                simulated_bus_memory_pkg.read_from_address(
                    net => net,
                    actor => slaveActor,
                    addr => expectedWriteAddress,
                    data => memReadData);
                check_equal(memReadData, expectedWriteData);
            elsif run("Requesting write then read works as expected") then
                expectedWriteData := X"AABBCCDD";
                expectedWriteAddress := X"00000008";
                dataIn <= expectedWriteData;
                address <= expectedWriteAddress;
                doWrite <= true;
                wait until rising_edge(clk) and not stall;
                doWrite <= false;
                doRead <= true;
                wait until rising_edge(clk) and not stall;
                check_equal(dataOut, expectedWriteData);
            elsif run("Bus fault blocks device") then
                expectedWriteData := X"AABBCCDD";
                expectedWriteAddress := X"10000000";
                dataIn <= expectedWriteData;
                address <= expectedWriteAddress;
                doWrite <= true;
                wait until rising_edge(clk) and hasFault;
                check_equal(faultData, bus_fault_address_out_of_range);
                check(stall);
            elsif run("Reset fixes bus fault block") then
                expectedWriteData := X"AABBCCDD";
                expectedWriteAddress := X"10000000";
                dataIn <= expectedWriteData;
                address <= expectedWriteAddress;
                doWrite <= true;
                wait until rising_edge(clk) and hasFault;
                doWrite <= false;
                rst <= '1';
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check(not stall);
            elsif run("Reading same thing twice results in one stall") then
                writeAddress := X"00000004";
                writeData := X"01234567";
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => slaveActor,
                    addr => writeAddress,
                    mask => (others => '1'),
                    data => writeData);
                doRead <= true;
                address <= writeAddress;
                wait until rising_edge(clk) and not stall;
                wait until rising_edge(clk);
                check(not stall);
            elsif run("Writing the same thing twice results in one stall") then
                expectedWriteData := X"AABBCCDD";
                expectedWriteAddress := X"00000008";
                dataIn <= expectedWriteData;
                address <= expectedWriteAddress;
                doWrite <= true;
                wait until rising_edge(clk) and not stall;
                wait until rising_edge(clk);
                check(not stall);
            elsif run("forbidBusInteraction prevents bus interaction") then
                expectedWriteData := X"AABBCCDD";
                expectedWriteAddress := X"00000008";
                dataIn <= expectedWriteData;
                address <= expectedWriteAddress;
                doWrite <= true;
                forbidBusInteraction <= true;
                wait until rising_edge(clk);
                check(stall);
                wait until falling_edge(clk);
                check(not bus_requesting(mst2slv));
            elsif run("Flushing the cache does lead to two reads") then
                writeAddress := X"00000004";
                writeData := X"01234567";
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => slaveActor,
                    addr => writeAddress,
                    mask => (others => '1'),
                    data => writeData);
                doRead <= true;
                address <= writeAddress;
                wait until rising_edge(clk) and not stall;
                flushCache <= true;
                wait until rising_edge(clk);
                flushCache <= false;
                wait until rising_edge(clk);
                check(stall);
                wait until falling_edge(clk);
                check(bus_requesting(mst2slv));
            elsif run("Relevant write after read should reread") then
                writeAddress := X"00000004";
                writeData := X"01234567";
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => slaveActor,
                    addr => writeAddress,
                    mask => (others => '1'),
                    data => writeData);
                doRead <= true;
                address <= writeAddress;
                wait until rising_edge(clk) and not stall;
                writeData := X"AAAABBBB";
                dataIn <= writeData;
                doRead <= false;
                doWrite <= true;
                wait until rising_edge(clk) and not stall;
                doWrite <= false;
                doRead <= true;
                wait until rising_edge(clk) and not stall;
                check_equal(dataOut, writeData);
            elsif run("no-op after write should rewrite") then
                writeAddress := X"00000004";
                doWrite <= true;
                address <= writeAddress;
                dataIn <= writeData;
                wait until rising_edge(clk) and not stall;
                doWrite <= false;
                wait until rising_edge(clk);
                doWrite <= true;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check(bus_requesting(mst2slv));
            elsif run("no-op after read should reread") then
                writeAddress := X"00000004";
                writeData := X"01234567";
                doRead <= true;
                address <= writeAddress;
                wait until rising_edge(clk) and not stall;
                doRead <= false;
                wait until rising_edge(clk);
                doRead <= true;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check(bus_requesting(mst2slv));
            elsif run("Bytemask is forwarded during read") then
                wait until falling_edge(clk);
                writeAddress := X"00000004";
                writeData := X"01234567";
                doRead <= true;
                address <= writeAddress;
                byteMask <= "0001";
                wait until falling_edge(clk);
                check(mst2slv.byteMask = byteMask);
            elsif run("Bytemask is forwarded during write") then
                wait until falling_edge(clk);
                writeAddress := X"00000004";
                writeData := X"01234567";
                doWrite <= true;
                address <= writeAddress;
                byteMask <= "0001";
                wait until falling_edge(clk);
                check(mst2slv.byteMask = byteMask);
            elsif run("Different bytemask should force reread") then
                writeAddress := X"00000004";
                writeData := X"01234567";
                doRead <= true;
                address <= writeAddress;
                byteMask <= "0001";
                wait until rising_edge(clk) and not stall;
                wait until falling_edge(clk);
                byteMask <= "1111";
                wait until falling_edge(clk);
                check(bus_requesting(mst2slv));
            elsif run("Different bytemask should force rewrite") then
                writeAddress := X"00000004";
                doWrite <= true;
                address <= writeAddress;
                dataIn <= writeData;
                byteMask <= "0001";
                wait until rising_edge(clk) and not stall;
                wait until falling_edge(clk);
                byteMask <= "1111";
                wait until falling_edge(clk);
                check(bus_requesting(mst2slv));
            elsif run("Reads in dcache range resolve correctly") then
                writeAddress := std_logic_vector(to_unsigned(cache_range_start, writeAddress'length));
                writeData := X"F1F2F3F4";
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => slaveActor,
                    addr => writeAddress,
                    mask => (others => '1'),
                    data => writeData);
                wait until falling_edge(clk);
                doRead <= true;
                address <= std_logic_vector(to_unsigned(cache_range_start, address'length));
                byteMask <= "1111";
                wait until rising_edge(clk) and not stall;
                check_equal(dataOut, std_logic_vector'(X"F1F2F3F4"));
            elsif run("Reads in dcache range are cached") then
                writeAddress := std_logic_vector(to_unsigned(cache_range_start, writeAddress'length));
                writeData := X"F1F2F3F4";
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => slaveActor,
                    addr => writeAddress,
                    mask => (others => '1'),
                    data => writeData);
                writeAddress := std_logic_vector(to_unsigned(cache_range_start + 4, writeAddress'length));
                writeData := X"01020304";
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => slaveActor,
                    addr => writeAddress,
                    mask => (others => '1'),
                    data => writeData);
                wait until falling_edge(clk);
                doRead <= true;
                address <= std_logic_vector(to_unsigned(cache_range_start, address'length));
                byteMask <= "1111";
                wait until rising_edge(clk) and not stall;
                doRead <= true;
                address <= std_logic_vector(to_unsigned(cache_range_start + 4, address'length));
                byteMask <= "1111";
                wait until rising_edge(clk) and not stall;
                doRead <= true;
                address <= std_logic_vector(to_unsigned(cache_range_start, address'length));
                byteMask <= "1111";
                wait until rising_edge(clk);
                check(not stall);
                check_equal(dataOut, std_logic_vector'(X"F1F2F3F4"));
            elsif run("Word aligned byte read in dcache range caches entire word") then
                writeAddress := std_logic_vector(to_unsigned(cache_range_start, writeAddress'length));
                writeData := X"F1F2F3F4";
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => slaveActor,
                    addr => writeAddress,
                    mask => (others => '1'),
                    data => writeData);
                wait until falling_edge(clk);
                doRead <= true;
                address <= std_logic_vector(to_unsigned(cache_range_start, address'length));
                byteMask <= "0001";
                wait until rising_edge(clk) and not stall;
                doRead <= true;
                address <= std_logic_vector(to_unsigned(cache_range_start, address'length));
                byteMask <= "0010";
                wait until rising_edge(clk);
                check(not stall);
                check_equal(dataOut(15 downto 8), std_logic_vector'(X"F3"));
            elsif run("Cache hitting write updates the cache") then
                writeAddress := std_logic_vector(to_unsigned(cache_range_start, writeAddress'length));
                writeData := X"F1F2F3F4";
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => slaveActor,
                    addr => writeAddress,
                    mask => (others => '1'),
                    data => writeData);
                wait until falling_edge(clk);
                doRead <= true;
                address <= std_logic_vector(to_unsigned(cache_range_start, address'length));
                byteMask <= (others => '1');
                wait until rising_edge(clk) and not stall;
                doRead <= false;
                doWrite <= true;
                address <= std_logic_vector(to_unsigned(cache_range_start, address'length));
                dataIn <= X"01020304";
                byteMask <= "1111";
                wait until rising_edge(clk) and not stall;
                doRead <= true;
                address <= std_logic_vector(to_unsigned(cache_range_start, address'length));
                byteMask <= (others => '1');
                wait until rising_edge(clk);
                check(not stall);
                check_equal(dataOut, std_logic_vector'(X"01020304"));
            elsif run("No write means no update") then
                writeAddress := std_logic_vector(to_unsigned(cache_range_start, writeAddress'length));
                writeData := X"F1F2F3F4";
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => slaveActor,
                    addr => writeAddress,
                    mask => (others => '1'),
                    data => writeData);
                wait until falling_edge(clk);
                doRead <= true;
                address <= std_logic_vector(to_unsigned(cache_range_start, address'length));
                byteMask <= (others => '1');
                wait until rising_edge(clk) and not stall;
                doRead <= false;
                doWrite <= false;
                address <= std_logic_vector(to_unsigned(cache_range_start, address'length));
                dataIn <= X"01020304";
                byteMask <= "1111";
                wait until rising_edge(clk) and not stall;
                doRead <= true;
                address <= std_logic_vector(to_unsigned(cache_range_start, address'length));
                byteMask <= (others => '1');
                wait until rising_edge(clk);
                check(not stall);
                check_equal(dataOut, std_logic_vector'(X"F1F2F3F4"));
            elsif run("Unaligned read always stalls") then
                writeAddress := std_logic_vector(to_unsigned(cache_range_start, writeAddress'length));
                writeData := X"F1F2F3F4";
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => slaveActor,
                    addr => writeAddress,
                    mask => (others => '1'),
                    data => writeData);
                wait until falling_edge(clk);
                doRead <= true;
                address <= std_logic_vector(to_unsigned(cache_range_start, address'length));
                byteMask <= (others => '1');
                wait until rising_edge(clk) and not stall;
                doRead <= true;
                address <= std_logic_vector(to_unsigned(cache_range_start + 1, address'length));
                byteMask <= (others => '1');
                wait until rising_edge(clk);
                check(stall);
            elsif run("Unaligned read from cached data leads to bus_fault_unaligned_access") then
                writeAddress := std_logic_vector(to_unsigned(cache_range_start, writeAddress'length));
                writeData := X"F1F2F3F4";
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => slaveActor,
                    addr => writeAddress,
                    mask => (others => '1'),
                    data => writeData);
                wait until falling_edge(clk);
                doRead <= true;
                address <= std_logic_vector(to_unsigned(cache_range_start, address'length));
                byteMask <= (others => '1');
                wait until rising_edge(clk) and not stall;
                doRead <= true;
                address <= std_logic_vector(to_unsigned(cache_range_start + 1, address'length));
                byteMask <= (others => '1');
                wait until rising_edge(clk) and hasFault;
                check_equal(faultData, bus_fault_unaligned_access);
                check(stall);
            elsif run("Unaligned read from uncached data leads to bus_fault_unaligned_access") then
                writeAddress := std_logic_vector(to_unsigned(cache_range_start, writeAddress'length));
                writeData := X"F1F2F3F4";
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => slaveActor,
                    addr => writeAddress,
                    mask => (others => '1'),
                    data => writeData);
                wait until falling_edge(clk);
                doRead <= true;
                address <= std_logic_vector(to_unsigned(cache_range_start + 1, address'length));
                byteMask <= (others => '1');
                wait until rising_edge(clk) and hasFault;
                check_equal(faultData, bus_fault_unaligned_access);
                check(stall);
            elsif run("Unaligned non-request does not stall") then
                writeAddress := std_logic_vector(to_unsigned(cache_range_start, writeAddress'length));
                writeData := X"F1F2F3F4";
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => slaveActor,
                    addr => writeAddress,
                    mask => (others => '1'),
                    data => writeData);
                wait until falling_edge(clk);
                doRead <= true;
                address <= std_logic_vector(to_unsigned(cache_range_start, address'length));
                byteMask <= (others => '1');
                wait until rising_edge(clk) and not stall;
                doRead <= false;
                address <= std_logic_vector(to_unsigned(cache_range_start + 1, address'length));
                byteMask <= (others => '1');
                wait until rising_edge(clk);
                check(not stall);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 us);

    mem2bus : entity src.riscv32_mem2bus
    generic map (
        range_to_cache => range_to_cache,
        cache_word_count_log2b => 4
    ) port map (
        clk => clk,
        rst => rst,
        forbidBusInteraction => forbidBusInteraction,
        flushCache => flushCache,
        mst2slv => mst2slv,
        slv2mst => slv2mst,
        hasFault => hasFault,
        faultData => faultData,
        address => address,
        byteMask => byteMask,
        dataIn => dataIn,
        dataOut => dataOut,
        doWrite => doWrite,
        doRead => doRead,
        stall => stall
    );

    bus_slave : entity tb.simulated_bus_memory
    generic map (
        depth_log2b => 11,
        allow_unaligned_access => true,
        actor => slaveActor,
        read_delay => 5,
        write_delay => 5
    ) port map (
        clk => clk,
        mst2mem => mst2slv,
        mem2mst => slv2mst
    );
end architecture;
