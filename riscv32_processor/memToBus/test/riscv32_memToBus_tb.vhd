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

entity riscv32_memToBus_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_memToBus_tb is
    constant cachedMemActor : actor_t := new_actor("cachedMem");
    constant uncachedMemActor : actor_t := new_actor("uncachedMem");

    constant clk_period : time := 20 ns;
    signal clk : std_logic := '0';
    signal rst : boolean := false;

    signal flush_cache : boolean := false;
    signal cache_flush_busy : boolean;

    signal mst2slv : bus_mst2slv_type;
    signal slv2mst : bus_slv2mst_type := BUS_SLV2MST_IDLE;

    signal hasFault : boolean;

    signal address : riscv32_address_type := (others => '0');
    signal byteMask : riscv32_byte_mask_type := (others => '1');
    signal dataIn : riscv32_data_type := (others => '0');
    signal doWrite : boolean := false;
    signal doRead : boolean := false;
    signal stallIn : boolean := false;

    signal dataOut : riscv32_data_type;
    signal stallOut : boolean;

    signal demux2cachedMem : bus_mst2slv_type;
    signal cachedMem2demux : bus_slv2mst_type;

    signal demux2uncachedMem : bus_mst2slv_type;
    signal uncachedMem2demux : bus_slv2mst_type;

    constant address_map : addr_range_and_mapping_array := (
        address_range_and_map(
            low => std_logic_vector(to_unsigned(16#2000#, bus_address_type'length)),
            high => std_logic_vector(to_unsigned(16#2400# - 1, bus_address_type'length)),
            mapping => bus_map_constant(bus_address_type'high - 10, '0') & bus_map_range(10, 0)
        ),
        address_range_and_map(
            low => std_logic_vector(to_unsigned(16#3000#, bus_address_type'length)),
            high => std_logic_vector(to_unsigned(16#3020# - 1, bus_address_type'length)),
            mapping => bus_map_constant(bus_address_type'high - 5, '0') & bus_map_range(5, 0)
        )
    );
begin
    clk <= not clk after (clk_period/2);

    main : process
        variable data : bus_data_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Test reading word from cached memory") then
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => cachedMemActor,
                    addr => std_logic_vector'(X"00000000"),
                    mask => (others => '1'),
                    data => std_logic_vector'(X"01234567"));
                wait until falling_edge(clk);
                address <= X"00002000";
                doRead <= true;
                wait until rising_edge(clk) and not stallOut;
                check_equal(dataOut, std_logic_vector'(X"01234567"));
            elsif run("Rereading cached word should be instant") then
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => cachedMemActor,
                    addr => std_logic_vector'(X"00000000"),
                    mask => (others => '1'),
                    data => std_logic_vector'(X"01234567"));
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => cachedMemActor,
                    addr => std_logic_vector'(X"00000004"),
                    mask => (others => '1'),
                    data => std_logic_vector'(X"87654321"));
                wait until falling_edge(clk);
                address <= X"00002000";
                doRead <= true;
                wait until rising_edge(clk) and not stallOut;
                wait until falling_edge(clk);
                address <= X"00002004";
                doRead <= true;
                wait until rising_edge(clk) and not stallOut;
                wait until falling_edge(clk);
                address <= X"00002000";
                doRead <= true;
                wait until rising_edge(clk);
                check(not stallOut);
                check_equal(dataOut, std_logic_vector'(X"01234567"));
            elsif run("No request means no stall") then
                wait until rising_edge(clk);
                check_false(stallOut);
            elsif run("Reading byte from cached memory should trigger word read") then
                wait until falling_edge(clk);
                address <= X"00002000";
                byteMask <= "0001";
                doRead <= true;
                wait until rising_edge(clk) and bus_requesting(mst2slv);
                check_equal(mst2slv.byteMask, std_logic_vector'("1111"));
            elsif run("Reading byte from uncached memory should trigger byte read") then
                wait until falling_edge(clk);
                address <= X"00003000";
                byteMask <= "0001";
                doRead <= true;
                wait until rising_edge(clk) and bus_requesting(mst2slv);
                check_equal(mst2slv.byteMask, std_logic_vector'("0001"));
            elsif run("Reading word from uncached memory does not cause caching") then
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => cachedMemActor,
                    addr => std_logic_vector'(X"00000000"),
                    mask => (others => '1'),
                    data => std_logic_vector'(X"01234567"));
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => uncachedMemActor,
                    addr => std_logic_vector'(X"00000000"),
                    mask => (others => '1'),
                    data => std_logic_vector'(X"87654321"));
                wait until falling_edge(clk);
                address <= X"00003000";
                doRead <= true;
                wait until falling_edge(clk) and not stallOut;
                address <= X"00002000";
                doRead <= true;
                wait until falling_edge(clk) and not stallOut;
                check_equal(dataOut, std_logic_vector'(X"01234567"));
            elsif run("Two back-to-back reads from uncached memory reads twice") then
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => uncachedMemActor,
                    addr => std_logic_vector'(X"00000000"),
                    mask => (others => '1'),
                    data => std_logic_vector'(X"87654321"));
                wait until falling_edge(clk);
                address <= X"00003000";
                doRead <= true;
                wait until rising_edge(clk) and not stallOut;
                check_equal(dataOut, std_logic_vector'(X"87654321"));
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => uncachedMemActor,
                    addr => std_logic_vector'(X"00000000"),
                    mask => (others => '1'),
                    data => std_logic_vector'(X"01234567"));
                wait until rising_edge(clk) and not stallOut;
                check_equal(dataOut, std_logic_vector'(X"01234567"));
            elsif run("Valid cache does not prevent uncached read") then
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => cachedMemActor,
                    addr => std_logic_vector'(X"00000000"),
                    mask => (others => '1'),
                    data => std_logic_vector'(X"01234567"));
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => uncachedMemActor,
                    addr => std_logic_vector'(X"00000000"),
                    mask => (others => '1'),
                    data => std_logic_vector'(X"87654321"));
                wait until falling_edge(clk);
                address <= X"00002000";
                doRead <= true;
                wait until falling_edge(clk) and not stallOut;
                address <= X"00003000";
                doRead <= true;
                wait until falling_edge(clk) and not stallOut;
                check_equal(dataOut, std_logic_vector'(X"87654321"));
            elsif run("Uncached read holds until stallIn becomes false") then
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => uncachedMemActor,
                    addr => std_logic_vector'(X"00000000"),
                    mask => (others => '1'),
                    data => std_logic_vector'(X"87654321"));
                wait until falling_edge(clk);
                address <= X"00003000";
                doRead <= true;
                stallIn <= true;
                wait until falling_edge(clk) and not stallOut;
                check_equal(dataOut, std_logic_vector'(X"87654321"));
                wait until falling_edge(clk);
                check_false(stallOut);
                check_equal(dataOut, std_logic_vector'(X"87654321"));
                stallIn <= true;
                doRead <= false;
                wait until falling_edge(clk);
                check_false(stallOut);
            elsif run("Write entire word from proc does update cache") then
                wait until falling_edge(clk);
                address <= X"00002000";
                doWrite <= true;
                dataIn <= X"F1F2F3F4";
                byteMask <= (others => '1');
                wait until falling_edge(clk);
                check_false(stallOut);
                doWrite <= false;
                check_equal(dataOut, dataIn);
            elsif run("Partial word write that misses only updates memory") then
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => cachedMemActor,
                    addr => std_logic_vector'(X"00000000"),
                    mask => (others => '1'),
                    data => std_logic_vector'(X"87654321"));
                wait until falling_edge(clk);
                address <= X"00002000";
                doWrite <= true;
                dataIn <= X"FFFFFFFF";
                byteMask <= "0011";
                wait until falling_edge(clk) and not stallOut;
                doWrite <= false;
                doRead <= true;
                wait until falling_edge(clk) and not stallOut;
                check_equal(dataOut, std_logic_vector'(X"8765FFFF"));
            elsif run("Partial word write that hits should update cache") then
                wait until falling_edge(clk);
                address <= X"00002000";
                doWrite <= true;
                dataIn <= X"87654321";
                byteMask <= (others => '1');
                wait until falling_edge(clk) and not stallOut;
                address <= X"00002000";
                doWrite <= true;
                dataIn <= X"FFFFFFFF";
                byteMask <= "0011";
                wait until falling_edge(clk) and not stallOut;
                doWrite <= false;
                doRead <= true;
                wait until falling_edge(clk) and not stallOut;
                check_equal(dataOut, std_logic_vector'(X"8765FFFF"));
                wait for clk_period;
                check_false(bus_requesting(mst2slv));
            elsif run("Dirty cache lines are written to memory") then
                wait until falling_edge(clk);
                address <= X"00002000";
                doWrite <= true;
                dataIn <= X"87654321";
                byteMask <= (others => '1');
                wait until falling_edge(clk) and not stallOut;
                address <= X"00002100";
                doWrite <= true;
                dataIn <= X"F1F2F3F4";
                byteMask <= (others => '1');
                wait until falling_edge(clk) and not stallOut;
                doWrite <= false;
                doRead <= true;
                wait until falling_edge(clk) and not stallOut;
                check_equal(dataOut, std_logic_vector'(X"F1F2F3F4"));
                address <= X"00002000";
                wait until falling_edge(clk) and not stallOut;
                check_equal(dataOut, std_logic_vector'(X"87654321"));
            elsif run("Missing read on dirty cache line commits cache line to memory") then
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => cachedMemActor,
                    addr => std_logic_vector'(X"00000100"),
                    mask => (others => '1'),
                    data => std_logic_vector'(X"01234567"));
                wait until falling_edge(clk);
                address <= X"00002000";
                doWrite <= true;
                dataIn <= X"87654321";
                byteMask <= (others => '1');
                wait until falling_edge(clk) and not stallOut;
                address <= X"00002100";
                doWrite <= false;
                doRead <= true;
                wait until falling_edge(clk) and not stallOut;
                check_equal(dataOut, std_logic_vector'(X"01234567"));
                address <= X"00002000";
                doWrite <= false;
                doRead <= true;
                wait until falling_edge(clk) and not stallOut;
                check_equal(dataOut, std_logic_vector'(X"87654321"));
            elsif run("Commit three writes to the same line") then
                wait until falling_edge(clk);
                address <= X"00002000";
                doWrite <= true;
                dataIn <= X"87654321";
                byteMask <= (others => '1');
                wait until rising_edge(clk) and not stallOut;
                address <= X"00002100";
                doWrite <= true;
                dataIn <= X"01234567";
                byteMask <= (others => '1');
                wait until rising_edge(clk) and not stallOut;
                address <= X"00002200";
                doWrite <= true;
                dataIn <= X"F0F1F2F3";
                byteMask <= (others => '1');
                wait until rising_edge(clk) and not stallOut;
                address <= X"00002000";
                doWrite <= false;
                doRead <= true;
                wait until rising_edge(clk) and not stallOut;
                check_equal(dataOut, std_logic_vector'(X"87654321"));
                address <= X"00002100";
                wait until rising_edge(clk) and not stallOut;
                check_equal(dataOut, std_logic_vector'(X"01234567"));
                address <= X"00002200";
                wait until rising_edge(clk) and not stallOut;
                check_equal(dataOut, std_logic_vector'(X"F0F1F2F3"));
            elsif run("Uncached write into uncached read") then
                wait until falling_edge(clk);
                address <= X"00003000";
                doWrite <= true;
                dataIn <= X"87654321";
                byteMask <= (others => '1');
                wait until rising_edge(clk) and not stallOut;
                address <= X"00003000";
                doWrite <= false;
                doRead <= true;
                wait until rising_edge(clk) and not stallOut;
                check_equal(dataOut, std_logic_vector'(X"87654321"));
            elsif run("Uncached read should not trigger write to memory") then
                wait until falling_edge(clk);
                address <= X"00002100";
                doWrite <= true;
                dataIn <= X"87654321";
                byteMask <= (others => '1');
                wait until rising_edge(clk) and not stallOut;
                address <= X"00003000";
                doWrite <= false;
                doRead <= true;
                wait until rising_edge(clk) and not stallOut;
                doRead <= false;
                wait for 20*clk_period;
                check_false(stallOut);
                simulated_bus_memory_pkg.read_from_address(
                    net => net,
                    actor => cachedMemActor,
                    addr => std_logic_vector'(X"00000100"),
                    data => data);
                check_false(data = std_logic_vector'(X"87654321"));
            elsif run("Test faulty read") then
                wait until falling_edge(clk);
                address <= X"00004000";
                doWrite <= false;
                doRead <= true;
                wait until rising_edge(clk) and not stallOut;
                check_true(hasFault);
            elsif run("Cache flush flushes cache") then
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => cachedMemActor,
                    addr => std_logic_vector'(X"00000000"),
                    mask => (others => '1'),
                    data => std_logic_vector'(X"01234567"));
                wait until falling_edge(clk);
                address <= X"00002004";
                doWrite <= true;
                dataIn <= X"F0002004";
                byteMask <= (others => '1');
                wait until rising_edge(clk) and not stallOut;
                address <= X"00002008";
                doWrite <= true;
                dataIn <= X"F0002008";
                byteMask <= (others => '1');
                wait until rising_edge(clk) and not stallOut;
                address <= X"00002014";
                doWrite <= true;
                dataIn <= X"F0002014";
                byteMask <= (others => '1');
                wait until rising_edge(clk) and not stallOut;
                doWrite <= false;
                flush_cache <= true;
                wait until rising_edge(clk);
                check_true(stallOut);
                flush_cache <= false;
                wait until rising_edge(clk);
                check_true(stallOut);
                check_true(cache_flush_busy);
                wait until rising_edge(clk) and not cache_flush_busy;
                wait until rising_edge(clk) and not stallOut;
                simulated_bus_memory_pkg.read_from_address(
                    net => net,
                    actor => cachedMemActor,
                    addr => std_logic_vector'(X"00000000"),
                    data => data);
                check_equal(data, std_logic_vector'(X"01234567"));
                simulated_bus_memory_pkg.read_from_address(
                    net => net,
                    actor => cachedMemActor,
                    addr => std_logic_vector'(X"00000004"),
                    data => data);
                check_equal(data, std_logic_vector'(X"F0002004"));
                simulated_bus_memory_pkg.read_from_address(
                    net => net,
                    actor => cachedMemActor,
                    addr => std_logic_vector'(X"00000008"),
                    data => data);
                check_equal(data, std_logic_vector'(X"F0002008"));
                simulated_bus_memory_pkg.read_from_address(
                    net => net,
                    actor => cachedMemActor,
                    addr => std_logic_vector'(X"00000014"),
                    data => data);
                check_equal(data, std_logic_vector'(X"F0002014"));
            elsif run("After a cache flush, the cache is reset") then
                wait until falling_edge(clk);
                address <= X"00002000";
                doWrite <= true;
                dataIn <= X"F0002004";
                byteMask <= (others => '1');
                wait until rising_edge(clk) and not stallOut;
                doWrite <= false;
                flush_cache <= true;
                wait until rising_edge(clk);
                flush_cache <= false;
                wait until rising_edge(clk) and not stallOut;
                simulated_bus_memory_pkg.write_to_address(
                    net => net,
                    actor => cachedMemActor,
                    addr => std_logic_vector'(X"00000000"),
                    mask => (others => '1'),
                    data => std_logic_vector'(X"01234567"));
                doRead <= true;
                wait until rising_edge(clk) and not stallOut;
                check_equal(dataOut, std_logic_vector'(X"01234567"));
            elsif run("Start cache flush together with uncached write") then
                wait until falling_edge(clk);
                address <= X"00002000";
                doWrite <= true;
                dataIn <= X"F0002000";
                byteMask <= (others => '1');
                wait until rising_edge(clk) and not stallOut;
                address <= X"00003000";
                doWrite <= true;
                dataIn <= X"87654321";
                byteMask <= (others => '1');
                flush_cache <= true;
                stallIn <= true;
                wait until rising_edge(clk);
                flush_cache <= false;
                wait until rising_edge(clk) and not stallOut;
                flush_cache <= false;
                doWrite <= false;
                simulated_bus_memory_pkg.read_from_address(
                    net => net,
                    actor => cachedMemActor,
                    addr => std_logic_vector'(X"00000000"),
                    data => data);
                check_equal(data, std_logic_vector'(X"F0002000"));
                simulated_bus_memory_pkg.read_from_address(
                    net => net,
                    actor => uncachedMemActor,
                    addr => std_logic_vector'(X"00000000"),
                    data => data);
                check_equal(data, std_logic_vector'(X"87654321"));
            elsif run("Start cache flush together with cache-updating write") then
                wait until falling_edge(clk);
                address <= X"00002000";
                doWrite <= true;
                dataIn <= X"AAAAAAAA";
                byteMask <= (others => '1');
                wait until rising_edge(clk) and not stallOut;
                address <= X"00002000";
                doWrite <= true;
                dataIn <= X"FFFFFFFF";
                byteMask <= "0101";
                flush_cache <= true;
                stallIn <= true;
                wait until rising_edge(clk);
                flush_cache <= false;
                wait until rising_edge(clk) and not stallOut;
                simulated_bus_memory_pkg.read_from_address(
                    net => net,
                    actor => cachedMemActor,
                    addr => std_logic_vector'(X"00000000"),
                    data => data);
                check_equal(data, std_logic_vector'(X"AAFFAAFF"));
            elsif run("Back to back uncached writes") then
                wait until falling_edge(clk);
                address <= X"00003000";
                doWrite <= true;
                dataIn <= X"AAAAAAAA";
                byteMask <= (others => '1');
                wait until rising_edge(clk) and not stallOut;
                address <= X"00003004";
                doWrite <= true;
                dataIn <= X"FFFFFFFF";
                byteMask <= (others => '1');
                wait until rising_edge(clk) and not stallOut;
                simulated_bus_memory_pkg.read_from_address(
                    net => net,
                    actor => uncachedMemActor,
                    addr => std_logic_vector'(X"00000000"),
                    data => data);
                check_equal(data, std_logic_vector'(X"AAAAAAAA"));
                simulated_bus_memory_pkg.read_from_address(
                    net => net,
                    actor => uncachedMemActor,
                    addr => std_logic_vector'(X"00000004"),
                    data => data);
                check_equal(data, std_logic_vector'(X"FFFFFFFF"));
            elsif run("Update cached address multiple times") then
                wait until falling_edge(clk);
                address <= X"00002000";
                doWrite <= true;
                dataIn <= X"01234567";
                byteMask <= (others => '1');
                wait until rising_edge(clk) and not stallOut;
                address <= X"00002000";
                doWrite <= true;
                dataIn <= X"87654321";
                byteMask <= (others => '1');
                wait until rising_edge(clk) and not stallOut;
                doWrite <= false;
                doRead <= true;
                wait for 1 ns;
                check_equal(dataOut, std_logic_vector'(X"87654321"));
            elsif run("Write cached word byte-by-byte") then
                wait until falling_edge(clk);
                address <= X"00002000";
                doWrite <= true;
                dataIn <= X"33221100";
                byteMask <= "0001";
                wait until rising_edge(clk) and not stallOut;
                address <= X"00002000";
                doWrite <= true;
                dataIn <= X"33221100";
                byteMask <= "0010";
                wait until rising_edge(clk) and not stallOut;
                address <= X"00002000";
                doWrite <= true;
                dataIn <= X"33221100";
                byteMask <= "0100";
                wait until rising_edge(clk) and not stallOut;
                address <= X"00002000";
                doWrite <= true;
                dataIn <= X"33221100";
                byteMask <= "1000";
                wait until rising_edge(clk) and not stallOut;
                doWrite <= false;
                doRead <= true;
                byteMask <= (others => '1');
                wait until rising_edge(clk) and not stallOut;
                check_equal(dataOut, std_logic_vector'(X"33221100"));
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  100 us);

    memToBus : entity src.riscv32_memToBus
    generic map (
        range_to_cache => address_map(0).addr_range,
        cache_word_count_log2b => 4
    ) port map (
        clk => clk,
        rst => rst,
        flush_cache => flush_cache,
        cache_flush_busy => cache_flush_busy,
        mst2slv => mst2slv,
        slv2mst => slv2mst,
        hasFault => hasFault,
        address => address,
        byteMask => byteMask,
        dataIn => dataIn,
        doWrite => doWrite,
        doRead => doRead,
        stallIn => stallIn,
        dataOut => dataOut,
        stallOut => stallOut
    );

    demux : entity src.bus_demux
    generic map (
        address_map => address_map
    ) port map (
        mst2demux => mst2slv,
        demux2mst => slv2mst,
        demux2slv(0) => demux2cachedMem,
        demux2slv(1) => demux2uncachedMem,
        slv2demux(0) => cachedMem2demux,
        slv2demux(1) => uncachedMem2demux
    );

    cached_mem : entity work.simulated_bus_memory
    generic map (
        depth_log2b => 10,
        allow_unaligned_access => true,
        actor => cachedMemActor,
        read_delay => 5,
        write_delay => 5
    ) port map (
        clk => clk,
        mst2mem => demux2cachedMem,
        mem2mst => cachedMem2demux
    );

    uncached_mem : entity work.simulated_bus_memory
    generic map (
        depth_log2b => 5,
        allow_unaligned_access => true,
        actor => uncachedMemActor,
        read_delay => 5,
        write_delay => 5
    ) port map (
        clk => clk,
        mst2mem => demux2uncachedMem,
        mem2mst => uncachedMem2demux
    );

    test_runner_watchdog(runner, 10 ms);
end architecture;
