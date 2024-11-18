library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg.all;
use src.riscv32_pkg.all;

library tb;
use tb.simulated_bus_memory_pkg;

entity riscv32_processor_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_processor_tb is
    constant clk_period : time := 20 ns;
    constant memoryAddress : natural := 16#100000#;
    constant outputMemoryAddress : natural := 16#200000#;
    constant controllerAddress : natural := 16#2000#;
    constant resetAddress : riscv32_address_type := std_logic_vector(to_unsigned(memoryAddress, riscv32_address_type'length));
    constant iCache_rangeMap : addr_range_and_mapping_type :=
        address_range_and_map(
            low => std_logic_vector(to_unsigned(16#100000#, bus_address_type'length)),
            high => std_logic_vector(to_unsigned(16#160000# - 1, bus_address_type'length)),
            mapping => bus_map_constant(bus_address_type'high - 18, '0') & bus_map_range(18, 0)
        );
    constant iCache_word_count_log2b : natural := 8;
    constant dCache_word_count_log2b : natural := 8;

    constant memActor : actor_t := new_actor("slave");
    constant outputMemActor : actor_t := new_actor("outputMemSlave");

    signal clk : std_logic := '0';
    signal rst : boolean;
    signal demux2control : bus_mst2slv_type;
    signal control2demux : bus_slv2mst_type;

    signal instructionFetch2arbiter : bus_mst2slv_type;
    signal arbiter2instructionFetch : bus_slv2mst_type;

    signal memory2arbiter : bus_mst2slv_type;
    signal arbiter2memory : bus_slv2mst_type;

    signal arbiter2demux : bus_mst2slv_type;
    signal demux2arbiter : bus_slv2mst_type;

    signal demux2mem : bus_mst2slv_type;
    signal mem2demux : bus_slv2mst_type;

    signal demux2outputMem : bus_mst2slv_type;
    signal outputMem2demux : bus_slv2mst_type;

    signal test2slv : bus_mst2slv_type := BUS_MST2SLV_IDLE;
    signal slv2test : bus_slv2mst_type;

    signal reset_request : boolean;

    constant address_map : addr_range_and_mapping_array := (
        address_range_and_map(
            low => std_logic_vector(to_unsigned(controllerAddress, bus_address_type'length)),
            high => std_logic_vector(to_unsigned(16#2100# - 1, bus_address_type'length)),
            mapping => bus_map_constant(bus_address_type'high - 8, '0') & bus_map_range(8, 0)
        ),
        address_range_and_map(
            low => std_logic_vector(to_unsigned(memoryAddress, bus_address_type'length)),
            high => std_logic_vector(to_unsigned(16#160000# - 1, bus_address_type'length)),
            mapping => bus_map_constant(bus_address_type'high - 18, '0') & bus_map_range(18, 0)
        ),
        address_range_and_map(
            low => std_logic_vector(to_unsigned(outputMemoryAddress, bus_address_type'length)),
            high => std_logic_vector(to_unsigned(16#260000# - 1, bus_address_type'length)),
            mapping => bus_map_constant(bus_address_type'high - 18, '0') & bus_map_range(18, 0)
        )
    );

    procedure start_cpu (signal mst2slv : inout bus_mst2slv_type; signal slv2mst : in bus_slv2mst_type) is
    begin
        mst2slv <= bus_mst2slv_write(
            address => std_logic_vector(to_unsigned(controllerAddress, bus_address_type'length)),
            write_data => (others => '0'),
            byte_mask => (others => '1'));
        wait until rising_edge(clk) and any_transaction(mst2slv, slv2mst);
        check(write_transaction(mst2slv, slv2mst));
        mst2slv <= BUS_MST2SLV_IDLE;
    end procedure;

    procedure reset_cpu (signal mst2slv : inout bus_mst2slv_type; signal slv2mst : in bus_slv2mst_type) is
    begin
        mst2slv <= bus_mst2slv_write(
            address => std_logic_vector(to_unsigned(controllerAddress, bus_address_type'length)),
            write_data => X"00000001",
            byte_mask => (others => '1'));
        wait until rising_edge(clk) and any_transaction(mst2slv, slv2mst);
        check(write_transaction(mst2slv, slv2mst));
        mst2slv <= BUS_MST2SLV_IDLE;
    end procedure;

    procedure flush_cache (signal mst2slv : inout bus_mst2slv_type; signal slv2mst : in bus_slv2mst_type) is
        constant writeData : bus_data_type := (2 => '1', others => '0');
    begin
        mst2slv <= bus_mst2slv_write(
            address => std_logic_vector(to_unsigned(controllerAddress, bus_address_type'length)),
            write_data => writeData,
            byte_mask => (others => '1'));
        wait until rising_edge(clk) and any_transaction(mst2slv, slv2mst);
        check(write_transaction(mst2slv, slv2mst));
        mst2slv <= BUS_MST2SLV_IDLE;
        while true loop
            wait for 20 * clk_period;
            mst2slv <= bus_mst2slv_read(
                address => std_logic_vector(to_unsigned(controllerAddress + 16, bus_address_type'length)));
            wait until rising_edge(clk) and any_transaction(mst2slv, slv2mst);
            mst2slv <= BUS_MST2SLV_IDLE;
            check(read_transaction(mst2slv, slv2mst));
            exit when slv2mst.readData(0) = '0';
        end loop;
    end procedure;


    procedure check_word_at_address(
        signal net : inout network_t;
        constant address : in bus_address_type;
        constant data : in bus_data_type) is
        variable readData : bus_data_type;
    begin
        simulated_bus_memory_pkg.read_from_address(
            net => net,
            actor => memActor,
            addr => address,
            data => readData);
        check_equal(readData, data);
    end procedure;

    procedure check_word_at_address_in_outMem(
        signal net : inout network_t;
        constant address : in bus_address_type;
        constant data : in bus_data_type) is
        variable readData : bus_data_type;
    begin
        simulated_bus_memory_pkg.read_from_address(
            net => net,
            actor => outputMemActor,
            addr => address,
            data => readData);
        check_equal(readData, data);
    end procedure;
begin

    rst <= reset_request;

    clk <= not clk after (clk_period/2);
    main : process
        variable readAddr : bus_address_type;
        variable readData : bus_data_type;
        variable expectedReadData : bus_data_type;
        variable curAddr : natural;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Store and read eleven") then
                simulated_bus_memory_pkg.write_file_to_address(net, memActor, 0, "./riscv32_processor/test/programs/storeEleven.txt");
                start_cpu(test2slv, slv2test);
                wait for 100*clk_period;
                flush_cache(test2slv, slv2test);
                expectedReadData := X"0000000b";
                readAddr := std_logic_vector(to_unsigned(16#14#, bus_address_type'length));
                check_word_at_address(net, readAddr, expectedReadData);
            elsif run("Load, add and store") then
                simulated_bus_memory_pkg.write_file_to_address(net, memActor, 0, "./riscv32_processor/test/programs/loadThenStore.txt");
                start_cpu(test2slv, slv2test);
                wait for 100*clk_period;
                flush_cache(test2slv, slv2test);
                expectedReadData := X"0000000e";
                readAddr := std_logic_vector(to_unsigned(16#1c#, bus_address_type'length));
                check_word_at_address(net, readAddr, expectedReadData);
            elsif run("Looped add") then
                simulated_bus_memory_pkg.write_file_to_address(net, memActor, 0, "./riscv32_processor/test/programs/loopedAdd.txt");
                start_cpu(test2slv, slv2test);
                wait for 20 us;
                flush_cache(test2slv, slv2test);
                expectedReadData := X"00000007";
                readAddr := std_logic_vector(to_unsigned(16#24#, bus_address_type'length));
                check_word_at_address(net, readAddr, expectedReadData);
            elsif run("Bubblesort") then
                simulated_bus_memory_pkg.write_file_to_address(net, memActor, 0, "./riscv32_processor/test/programs/minimalBubblesort.txt");
                start_cpu(test2slv, slv2test);
                wait for 500 us;
                flush_cache(test2slv, slv2test);
                curAddr := 16#15c#;
                for i in -6 to 5 loop
                    readAddr := std_logic_vector(to_unsigned(curAddr, bus_address_type'length));
                    expectedReadData := std_logic_vector(to_signed(i, expectedReadData'length));
                    check_word_at_address(net, readAddr, expectedReadData);
                    curAddr := curAddr + 4;
                end loop;
                curAddr := 16#18c#;
                for i in -3 to 2 loop
                    readAddr := std_logic_vector(to_unsigned(curAddr, readAddr'length));
                    expectedReadData(31 downto 16) := std_logic_vector(to_signed(i*2 + 1, 16));
                    expectedReadData(15 downto 0) := std_logic_vector(to_signed(i*2, 16));
                    check_word_at_address(net, readAddr, expectedReadData);
                    curAddr := curAddr + 4;
                end loop;
                curAddr := 16#1a4#;
                for i in 0 to 2 loop
                    readAddr := std_logic_vector(to_unsigned(curAddr, readAddr'length));
                    expectedReadData(31 downto 24) := std_logic_vector(to_signed(i*4 - 3, 8));
                    expectedReadData(23 downto 16) := std_logic_vector(to_signed(i*4 - 4, 8));
                    expectedReadData(15 downto 8) := std_logic_vector(to_signed(i*4 - 5, 8));
                    expectedReadData(7 downto 0) := std_logic_vector(to_signed(i*4 - 6, 8));
                    check_word_at_address(net, readAddr, expectedReadData);
                    curAddr := curAddr + 4;
                end loop;
            elsif run("rdinstret") then
                simulated_bus_memory_pkg.write_file_to_address(net, memActor, 0, "./riscv32_processor/test/programs/rdinstret.txt");
                start_cpu(test2slv, slv2test);
                wait for 10 us;
                flush_cache(test2slv, slv2test);
                expectedReadData := X"0000000e";
                readAddr := std_logic_vector(to_unsigned(16#70#, bus_address_type'length));
                check_word_at_address(net, readAddr, expectedReadData);
            elsif run("Run, reset and then run again") then
                simulated_bus_memory_pkg.write_file_to_address(net, memActor, 0, "./riscv32_processor/test/programs/storeEleven.txt");
                start_cpu(test2slv, slv2test);
                wait for 20 us;
                reset_cpu(test2slv, slv2test);
                simulated_bus_memory_pkg.write_file_to_address(net, memActor, 0, "./riscv32_processor/test/programs/loopedAdd.txt");
                start_cpu(test2slv, slv2test);
                wait for 20 us;
                flush_cache(test2slv, slv2test);
                expectedReadData := X"00000007";
                readAddr := std_logic_vector(to_unsigned(16#24#, bus_address_type'length));
                check_word_at_address(net, readAddr, expectedReadData);
            elsif run("Instruction address fault test") then
                simulated_bus_memory_pkg.write_to_address(net, outputMemActor, X"00000000", X"FFFFFFFF", X"f");
                simulated_bus_memory_pkg.write_file_to_address(net, memActor, 0, "./riscv32_processor/test/programs/instructionAddressFault.txt");
                start_cpu(test2slv, slv2test);
                wait for 20 us;
                expectedReadData := X"00000001";
                readAddr := std_logic_vector(to_unsigned(16#0#, bus_address_type'length));
                check_word_at_address_in_outMem(net, readAddr, expectedReadData);
            elsif run("Instruction address unaligned fault test") then
                simulated_bus_memory_pkg.write_to_address(net, outputMemActor, X"00000000", X"FFFFFFFF", X"f");
                simulated_bus_memory_pkg.write_to_address(net, outputMemActor, X"00000004", X"FFFFFFFF", X"f");
                simulated_bus_memory_pkg.write_file_to_address(net, memActor, 0, "./riscv32_processor/test/programs/instructionAlignmentFault.txt");
                start_cpu(test2slv, slv2test);
                wait for 20 us;
                expectedReadData := X"00000000";
                readAddr := std_logic_vector(to_unsigned(16#0#, bus_address_type'length));
                check_word_at_address_in_outMem(net, readAddr, expectedReadData);
                expectedReadData := X"00100000";
                readAddr := std_logic_vector(to_unsigned(16#4#, bus_address_type'length));
                check_word_at_address_in_outMem(net, readAddr, expectedReadData);
            elsif run("Illegal instruction test") then
                simulated_bus_memory_pkg.write_to_address(net, outputMemActor, X"00000000", X"FFFFFFFF", X"f");
                simulated_bus_memory_pkg.write_to_address(net, outputMemActor, X"00000004", X"FFFFFFFF", X"f");
                simulated_bus_memory_pkg.write_file_to_address(net, memActor, 0, "./riscv32_processor/test/programs/illegalInstructionFault.txt");
                start_cpu(test2slv, slv2test);
                wait for 20 us;
                expectedReadData := X"00000002";
                readAddr := std_logic_vector(to_unsigned(16#0#, bus_address_type'length));
                check_word_at_address_in_outMem(net, readAddr, expectedReadData);
                expectedReadData := X"0010001c";
                readAddr := std_logic_vector(to_unsigned(16#4#, bus_address_type'length));
                check_word_at_address_in_outMem(net, readAddr, expectedReadData);
            elsif run("mret test") then
                simulated_bus_memory_pkg.write_to_address(net, outputMemActor, X"00000000", X"FFFFFFFF", X"f");
                simulated_bus_memory_pkg.write_to_address(net, outputMemActor, X"00000004", X"FFFFFFFF", X"f");
                simulated_bus_memory_pkg.write_to_address(net, outputMemActor, X"00000008", X"FFFFFFFF", X"f");
                simulated_bus_memory_pkg.write_file_to_address(net, memActor, 0, "./riscv32_processor/test/programs/mret.txt");
                start_cpu(test2slv, slv2test);
                wait for 20 us;
                expectedReadData := X"00000002";
                readAddr := std_logic_vector(to_unsigned(16#0#, bus_address_type'length));
                check_word_at_address_in_outMem(net, readAddr, expectedReadData);
                expectedReadData := X"0010001c";
                readAddr := std_logic_vector(to_unsigned(16#4#, bus_address_type'length));
                check_word_at_address_in_outMem(net, readAddr, expectedReadData);
                expectedReadData := X"00100024";
                readAddr := std_logic_vector(to_unsigned(16#8#, bus_address_type'length));
                check_word_at_address_in_outMem(net, readAddr, expectedReadData);
            elsif run("Illegal CSR write test") then
                simulated_bus_memory_pkg.write_to_address(net, outputMemActor, X"00000000", X"FFFFFFFF", X"f");
                simulated_bus_memory_pkg.write_to_address(net, outputMemActor, X"00000004", X"FFFFFFFF", X"f");
                simulated_bus_memory_pkg.write_to_address(net, outputMemActor, X"00000008", X"FFFFFFFF", X"f");
                simulated_bus_memory_pkg.write_to_address(net, outputMemActor, X"0000000C", X"FFFFFFFF", X"f");
                simulated_bus_memory_pkg.write_file_to_address(net, memActor, 0, "./riscv32_processor/test/programs/illegalCSRWrite.txt");
                start_cpu(test2slv, slv2test);
                wait for 20 us;
                expectedReadData := X"00000002";
                readAddr := std_logic_vector(to_unsigned(16#0#, bus_address_type'length));
                check_word_at_address_in_outMem(net, readAddr, expectedReadData);
                expectedReadData := X"00100024";
                readAddr := std_logic_vector(to_unsigned(16#4#, bus_address_type'length));
                check_word_at_address_in_outMem(net, readAddr, expectedReadData);
                expectedReadData := X"00100030";
                readAddr := std_logic_vector(to_unsigned(16#8#, bus_address_type'length));
                check_word_at_address_in_outMem(net, readAddr, expectedReadData);
                expectedReadData := X"FFFFFFFF";
                readAddr := std_logic_vector(to_unsigned(16#C#, bus_address_type'length));
                check_word_at_address_in_outMem(net, readAddr, expectedReadData);
            elsif run("unaligned address load test") then
                simulated_bus_memory_pkg.write_to_address(net, outputMemActor, X"00000000", X"00000000", X"f");
                simulated_bus_memory_pkg.write_to_address(net, outputMemActor, X"00000004", X"00000000", X"f");
                simulated_bus_memory_pkg.write_to_address(net, outputMemActor, X"00000008", X"00000000", X"f");
                simulated_bus_memory_pkg.write_to_address(net, outputMemActor, X"0000000C", X"00000000", X"f");
                simulated_bus_memory_pkg.write_file_to_address(net, memActor, 0, "./riscv32_processor/test/programs/unaligned_load.txt");
                start_cpu(test2slv, slv2test);
                wait for 20 us;
                expectedReadData := X"00000004";
                readAddr := std_logic_vector(to_unsigned(16#0#, bus_address_type'length));
                check_word_at_address_in_outMem(net, readAddr, expectedReadData);
                expectedReadData := X"00100020";
                readAddr := std_logic_vector(to_unsigned(16#4#, bus_address_type'length));
                check_word_at_address_in_outMem(net, readAddr, expectedReadData);
                expectedReadData := X"0010002c";
                readAddr := std_logic_vector(to_unsigned(16#8#, bus_address_type'length));
                check_word_at_address_in_outMem(net, readAddr, expectedReadData);
                expectedReadData := X"FFFFFFFF";
                readAddr := std_logic_vector(to_unsigned(16#C#, bus_address_type'length));
                check_word_at_address_in_outMem(net, readAddr, expectedReadData);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    processor : entity src.riscv32_processor
    generic map (
        startAddress => resetAddress,
        clk_period => clk_period,
        iCache_range => iCache_rangeMap.addr_range,
        iCache_word_count_log2b => iCache_word_count_log2b,
        dCache_range => iCache_rangeMap.addr_range,
        dCache_word_count_log2b => dCache_word_count_log2b
    ) port map (
        clk => clk,
        rst => rst,
        mst2control => demux2control,
        control2mst => control2demux,
        instructionFetch2slv => instructionFetch2arbiter,
        slv2instructionFetch => arbiter2instructionFetch,
        memory2slv => memory2arbiter,
        slv2memory => arbiter2memory,
        reset_request => reset_request
    );

    arbiter : entity src.bus_arbiter
    generic map (
        masterCount => 3
   ) port map (
        clk => clk,
        mst2arbiter(0) => instructionFetch2arbiter,
        mst2arbiter(1) => memory2arbiter,
        mst2arbiter(2) => test2slv,
        arbiter2mst(0) => arbiter2instructionFetch,
        arbiter2mst(1) => arbiter2memory,
        arbiter2mst(2) => slv2test,
        arbiter2slv => arbiter2demux,
        slv2arbiter => demux2arbiter
    );

   demux : entity src.bus_demux
   generic map (
        address_map => address_map
   ) port map (
        mst2demux => arbiter2demux,
        demux2mst => demux2arbiter,
        demux2slv(0) => demux2control,
        demux2slv(1) => demux2mem,
        demux2slv(2) => demux2outputMem,
        slv2demux(0) => control2demux,
        slv2demux(1) => mem2demux,
        slv2demux(2) => outputMem2demux
    );

   mem : entity work.simulated_bus_memory
   generic map (
        depth_log2b => 10,
        allow_unaligned_access => true,
        actor => memActor,
        read_delay => 5,
        write_delay => 5
    ) port map (
        clk => clk,
        mst2mem => demux2mem,
        mem2mst => mem2demux
    );

   outputMem : entity work.simulated_bus_memory
   generic map (
        depth_log2b => 4,
        allow_unaligned_access => true,
        actor => outputMemActor,
        read_delay => 5,
        write_delay => 5
    ) port map (
        clk => clk,
        mst2mem => demux2outputMem,
        mem2mst => outputMem2demux
    );

    test_runner_watchdog(runner, 10 ms);
end architecture;
