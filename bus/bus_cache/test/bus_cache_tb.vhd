library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg.all;
library tb;
use tb.simulated_bus_memory_pkg.all;

entity bus_cache_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of bus_cache_tb is
    constant clk_period : time := 20 ns;

    constant words_per_line_log2b : natural := 1;
    constant total_line_count_log2b : natural := 4;
    constant bank_count_log2b : natural := 2;

    constant words_per_line : natural := 2**words_per_line_log2b;
    constant total_line_count : natural := 2**total_line_count_log2b;
    constant bank_count : natural := 2**bank_count_log2b;

    constant total_words_in_cache : natural := words_per_line * total_line_count;

    constant memActor : actor_t := new_actor("slave");

    signal clk : std_logic := '0';
    signal rst : boolean := false;

    signal mst2frontend : bus_mst2slv_type := BUS_MST2SLV_IDLE;
    signal frontend2mst : bus_slv2mst_type;

    signal backend2slv : bus_mst2slv_type;
    signal slv2backend : bus_slv2mst_type;

    signal do_flush : boolean := false;
    signal flush_busy : boolean;

begin
    clk <= not clk after (clk_period/2);

    main : process
        variable memory_address : bus_address_type;
        variable memory_words : bus_data_array(0 to words_per_line - 1);
        variable memory_mask : bus_byte_mask_type;

        variable bus_address : bus_address_type;
        variable bus_write_data : bus_data_type;
        variable bus_byte_mask : bus_byte_mask_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Read complete word") then
                for i in 0 to words_per_line - 1 loop
                    memory_words(i) := std_logic_vector(to_unsigned(i, memory_words(i)'length));
                end loop;
                memory_address := std_logic_vector(to_unsigned(0, memory_address'length));
                memory_mask := (others => '1');
                write_to_address(net, memActor, memory_address, memory_words, memory_mask);
                wait until rising_edge(clk);
                mst2frontend <= bus_mst2slv_read(std_logic_vector(to_unsigned(0, bus_address_type'length)));
                wait until rising_edge(clk) and read_transaction(mst2frontend, frontend2mst);
                check_equal(frontend2mst.readData, std_logic_vector(to_unsigned(0, frontend2mst.readData'length)));
                mst2frontend <= bus_mst2slv_read(std_logic_vector(to_unsigned(4, bus_address_type'length)));
                wait until rising_edge(clk) and read_transaction(mst2frontend, frontend2mst);
                check_equal(frontend2mst.readData, std_logic_vector(to_unsigned(1, frontend2mst.readData'length)));
            elsif run("Write complete word") then
                for i in 0 to words_per_line - 1 loop
                    memory_words(i) := std_logic_vector(to_unsigned(i, memory_words(i)'length));
                end loop;
                memory_address := std_logic_vector(to_unsigned(0, memory_address'length));
                memory_mask := (others => '1');
                write_to_address(net, memActor, memory_address, memory_words, memory_mask);
                wait until rising_edge(clk);
                bus_address := std_logic_vector(to_unsigned(0, bus_address'length));
                bus_write_data := std_logic_vector(to_unsigned(14, bus_write_data'length));
                mst2frontend <= bus_mst2slv_write(bus_address, bus_write_data);
                wait until rising_edge(clk) and write_transaction(mst2frontend, frontend2mst);
                mst2frontend <= bus_mst2slv_read(bus_address);
                wait until rising_edge(clk) and read_transaction(mst2frontend, frontend2mst);
                check_equal(frontend2mst.readData, std_logic_vector(to_unsigned(14, frontend2mst.readData'length)));
            elsif run("Write bytemask is respected") then
                for i in 0 to words_per_line - 1 loop
                    memory_words(i) := std_logic_vector(to_unsigned(i, memory_words(i)'length));
                end loop;
                memory_address := std_logic_vector(to_unsigned(0, memory_address'length));
                memory_mask := (others => '1');
                write_to_address(net, memActor, memory_address, memory_words, memory_mask);
                wait until rising_edge(clk);
                bus_address := std_logic_vector(to_unsigned(0, bus_address'length));
                bus_write_data := (others => '1');
                bus_byte_mask := (others => '0');
                bus_byte_mask(0) := '1';
                mst2frontend <= bus_mst2slv_write(bus_address, bus_write_data, bus_byte_mask);
                wait until rising_edge(clk) and write_transaction(mst2frontend, frontend2mst);
                mst2frontend <= bus_mst2slv_read(bus_address);
                wait until rising_edge(clk) and read_transaction(mst2frontend, frontend2mst);
                check_equal(frontend2mst.readData(bus_byte_size - 1 downto 0), bus_write_data(bus_byte_size - 1 downto 0));
                check_equal(frontend2mst.readData(bus_data_type'high downto bus_byte_size), std_logic_vector(to_unsigned(0, bus_data_type'length - bus_byte_size)));
            elsif run("Read unaligned byte") then
                for i in 0 to words_per_line - 1 loop
                    memory_words(i) := std_logic_vector(to_unsigned(i, memory_words(i)'length));
                end loop;
                memory_address := std_logic_vector(to_unsigned(0, memory_address'length));
                memory_mask := (others => '1');
                write_to_address(net, memActor, memory_address, memory_words, memory_mask);
                wait until rising_edge(clk);
                bus_address := std_logic_vector(to_unsigned(0, bus_address'length));
                bus_write_data := (others => '1');
                bus_byte_mask := (others => '0');
                bus_byte_mask(bus_byte_mask'high) := '1';
                mst2frontend <= bus_mst2slv_write(bus_address, bus_write_data, bus_byte_mask);
                wait until rising_edge(clk) and write_transaction(mst2frontend, frontend2mst);
                bus_address := std_logic_vector(to_unsigned(0 + bus_bytes_per_word - 1, bus_address'length));
                bus_byte_mask := (others => '0');
                bus_byte_mask(0) := '1';
                mst2frontend <= bus_mst2slv_read(bus_address, bus_byte_mask);
                wait until rising_edge(clk) and read_transaction(mst2frontend, frontend2mst);
                check_equal(frontend2mst.readData(bus_byte_size - 1 downto 0), bus_write_data(bus_byte_size - 1 downto 0));
            elsif run("Write unaligned two-byte") then
                for i in 0 to words_per_line - 1 loop
                    memory_words(i) := std_logic_vector(to_unsigned(i, memory_words(i)'length));
                end loop;
                memory_address := std_logic_vector(to_unsigned(0, memory_address'length));
                memory_mask := (others => '1');
                write_to_address(net, memActor, memory_address, memory_words, memory_mask);
                wait until rising_edge(clk);
                bus_address := std_logic_vector(to_unsigned(2, bus_address'length));
                bus_write_data := (others => '1');
                bus_byte_mask := (others => '0');
                bus_byte_mask(0) := '1';
                bus_byte_mask(1) := '1';
                mst2frontend <= bus_mst2slv_write(bus_address, bus_write_data, bus_byte_mask);
                wait until rising_edge(clk) and write_transaction(mst2frontend, frontend2mst);
                bus_address := std_logic_vector(to_unsigned(0, bus_address'length));
                bus_byte_mask := (others => '1');
                mst2frontend <= bus_mst2slv_read(bus_address, bus_byte_mask);
                wait until rising_edge(clk) and read_transaction(mst2frontend, frontend2mst);
                for i in 0 to bus_bytes_per_word - 1 loop
                    if i < 2 then
                        check_true(or_reduce(frontend2mst.readData((i + 1)*bus_byte_size - 1 downto i*bus_byte_size)) = '0');
                    else
                        check_true(and_reduce(frontend2mst.readData((i + 1)*bus_byte_size - 1 downto i*bus_byte_size)) = '1');
                    end if;
                end loop;
            elsif run("Test erronous bytemask") then
                bus_address := std_logic_vector(to_unsigned(1, bus_address'length));
                bus_byte_mask := (others => '1');
                mst2frontend <= bus_mst2slv_read(bus_address, bus_byte_mask);
                wait until rising_edge(clk) and fault_transaction(mst2frontend, frontend2mst);
                check_equal(frontend2mst.faultData, bus_fault_illegal_byte_mask);
            elsif run("Backend error is reported on frontend") then
                bus_address := std_logic_vector(to_unsigned(1024, bus_address'length));
                bus_byte_mask := (others => '1');
                mst2frontend <= bus_mst2slv_read(bus_address, bus_byte_mask);
                wait until rising_edge(clk) and fault_transaction(mst2frontend, frontend2mst);
                check_equal(frontend2mst.faultData, bus_fault_address_out_of_range);
            elsif run("Check backend writeback") then
                for base_index in 0 to bank_count loop
                    for i in 0 to words_per_line - 1 loop
                        memory_words(i) := std_logic_vector(to_unsigned(i + base_index, memory_words(i)'length));
                    end loop;
                    memory_address := std_logic_vector(to_unsigned(base_index * total_line_count * words_per_line, memory_address'length));
                    memory_mask := (others => '1');
                    write_to_address(net, memActor, memory_address, memory_words, memory_mask);
                end loop;

                for base_index in 0 to bank_count loop
                    bus_address := std_logic_vector(to_unsigned(base_index * total_line_count * words_per_line, bus_address'length));
                    bus_write_data := std_logic_vector(to_unsigned(14, bus_write_data'length));
                    mst2frontend <= bus_mst2slv_write(bus_address, bus_write_data);
                    wait until rising_edge(clk) and write_transaction(mst2frontend, frontend2mst);
                end loop;

                for base_index in 0 to bank_count loop
                    bus_address := std_logic_vector(to_unsigned(base_index * total_line_count * words_per_line, bus_address'length));
                    mst2frontend <= bus_mst2slv_read(bus_address);
                    wait until rising_edge(clk) and read_transaction(mst2frontend, frontend2mst);
                    check_equal(frontend2mst.readData, std_logic_vector(to_unsigned(14, frontend2mst.readData'length)));
                end loop;
            elsif run("Test flushing") then
                memory_address := std_logic_vector(to_unsigned(0, memory_address'length));
                memory_mask := (others => '1');
                for i in 0 to words_per_line - 1 loop
                    memory_words(i) := (others => '1');
                end loop;
                write_to_address(net, memActor, memory_address, memory_words, memory_mask);
                wait until rising_edge(clk);
                bus_address := std_logic_vector(to_unsigned(0, bus_address'length));
                bus_write_data := std_logic_vector(to_unsigned(14, bus_write_data'length));
                mst2frontend <= bus_mst2slv_write(bus_address, bus_write_data);
                wait until rising_edge(clk) and write_transaction(mst2frontend, frontend2mst);
                mst2frontend <= BUS_MST2SLV_IDLE;
                do_flush <= true;
                wait until rising_edge(clk) and flush_busy;
                do_flush <= false;
                wait until rising_edge(clk) and not flush_busy;
                memory_address := std_logic_vector(to_unsigned(0, memory_address'length));
                read_from_address(net, memActor, memory_address, memory_words);
                check_equal(memory_words(0), std_logic_vector(to_unsigned(14, memory_words(0)'length)));
                check_true(and_reduce(memory_words(1)) = '1');
            elsif run("Test eviction") then
                memory_words := (others => (others => '1'));
                for i in 0 to total_words_in_cache / 2 loop
                    memory_address := std_logic_vector(to_unsigned(i*8, memory_address'length));
                    memory_mask := (others => '1');
                    write_to_address(net, memActor, memory_address, memory_words, memory_mask);
                end loop;
                -- Now we write into the frontend, all zeros
                for i in 0 to total_words_in_cache + 1 loop
                    bus_address := std_logic_vector(to_unsigned(i*4, bus_address'length));
                    info("Writing to bus address: " & to_string(i*4));
                    bus_write_data := (others => '0');
                    bus_byte_mask := (others => '1');
                    mst2frontend <= bus_mst2slv_write(bus_address, bus_write_data, bus_byte_mask);
                    wait until rising_edge(clk) and write_transaction(mst2frontend, frontend2mst);
                end loop;
                mst2frontend <= BUS_MST2SLV_IDLE;
                -- Now we need to read all the zeros back
                for i in 0 to total_words_in_cache + 1 loop
                    bus_address := std_logic_vector(to_unsigned(i*4, bus_address'length));
                    mst2frontend <= bus_mst2slv_read(bus_address);
                    wait until rising_edge(clk) and read_transaction(mst2frontend, frontend2mst);
                    check(or_reduce(frontend2mst.readData) = '0');
                end loop;
                mst2frontend <= BUS_MST2SLV_IDLE;
                -- Flush it, then check main memory
                do_flush <= true;
                wait until rising_edge(clk) and flush_busy;
                do_flush <= false;
                wait until rising_edge(clk) and not flush_busy;
                for i in 0 to total_words_in_cache / 2 loop
                    memory_address := std_logic_vector(to_unsigned(i*8, memory_address'length));
                    read_from_address(net, memActor, memory_address, memory_words);
                    info("Read from memory address: " & to_string(i*8));
                    check(or_reduce(memory_words(0)) = '0');
                    check(or_reduce(memory_words(1)) = '0');
                end loop;
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  50 us);

    bus_cache : entity src.bus_cache
    generic map (
        words_per_line_log2b => words_per_line_log2b,
        total_line_count_log2b => total_line_count_log2b,
        bank_count_log2b => bank_count_log2b
    ) port map (
        clk => clk,
        rst => rst,
        mst2frontend => mst2frontend,
        frontend2mst => frontend2mst,
        backend2slv => backend2slv,
        slv2backend => slv2backend,
        do_flush => do_flush,
        flush_busy => flush_busy
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
        mst2mem => backend2slv,
        mem2mst => slv2backend
    );
end architecture;
