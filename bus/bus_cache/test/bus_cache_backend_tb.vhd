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

entity bus_cache_backend_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of bus_cache_backend_tb is
    constant clk_period : time := 20 ns;
    constant words_per_line_log2b : natural := 2;

    constant words_per_line : natural := 2**words_per_line_log2b;

    constant memActor : actor_t := new_actor("slave");

    signal clk : std_logic := '0';
    signal rst : boolean := false;

    signal backend2slv : bus_mst2slv_type;
    signal slv2backend : bus_slv2mst_type;

    signal word_index : natural range 0 to words_per_line - 1;

    signal do_write : boolean := false;
    signal write_address : bus_address_type := (others => '0');
    signal write_data : bus_data_type := (others => '0');

    signal do_read : boolean := false;
    signal read_word_retrieved : boolean;
    signal read_address : bus_address_type := (others => '0');
    signal read_data : bus_data_type;

    signal line_complete : boolean;
    signal bus_fault : boolean;
    signal bus_fault_data : bus_fault_type;
begin
    clk <= not clk after (clk_period/2);

    main : process
        variable memory_address : bus_address_type;
        variable memory_words : bus_data_array(0 to words_per_line - 1);
        variable memory_mask : bus_byte_mask_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Initially, word index is 0") then
                check_equal(word_index, 0);
            elsif run("Do line write") then
                write_address <= std_logic_vector(to_unsigned(0, write_address'length));
                write_data <= std_logic_vector(to_unsigned(0, write_data'length));
                do_write <= true;
                wait until rising_edge(clk);
                do_write <= false;
                for i in 1 to words_per_line - 1 loop
                    wait until rising_edge(clk) and word_index = i;
                    write_data <= std_logic_vector(to_unsigned(i, write_data'length));
                end loop;
                wait until rising_edge(clk) and line_complete;
                memory_address := std_logic_vector(to_unsigned(0, memory_address'length));
                read_from_address(net, memActor, memory_address, memory_words);
                for i in 0 to words_per_line - 1 loop
                    check_equal(memory_words(i), std_logic_vector(to_unsigned(i, memory_words(i)'length)));
                end loop;
            elsif run("Test write fault response") then
                write_address <= std_logic_vector(to_unsigned(2**10, write_address'length));
                write_data <= std_logic_vector(to_unsigned(0, write_data'length));
                do_write <= true;
                wait until rising_edge(clk);
                do_write <= false;
                wait until rising_edge(clk) and bus_fault;
                check_equal(bus_fault_data, bus_fault_address_out_of_range);
            elsif run("Test write after write") then
                write_address <= std_logic_vector(to_unsigned(0, write_address'length));
                write_data <= std_logic_vector(to_unsigned(0, write_data'length));
                do_write <= true;
                wait until rising_edge(clk);
                do_write <= false;
                for i in 1 to words_per_line - 1 loop
                    wait until rising_edge(clk) and word_index = i;
                    write_data <= std_logic_vector(to_unsigned(i, write_data'length));
                end loop;
                wait until rising_edge(clk) and line_complete;
                check_equal(word_index, 0);
                write_address <= std_logic_vector(to_unsigned(words_per_line*bus_bytes_per_word, write_address'length));
                write_data <= std_logic_vector(to_unsigned(15, write_data'length));
                do_write <= true;
                wait until rising_edge(clk);
                do_write <= false;
                for i in 1 to words_per_line - 1 loop
                    wait until rising_edge(clk) and word_index = i;
                    write_data <= std_logic_vector(to_unsigned(15 + i, write_data'length));
                end loop;
                wait until rising_edge(clk) and line_complete;
                memory_address := std_logic_vector(to_unsigned(0, memory_address'length));
                read_from_address(net, memActor, memory_address, memory_words);
                for i in 0 to words_per_line - 1 loop
                    check_equal(memory_words(i), std_logic_vector(to_unsigned(i, memory_words(i)'length)));
                end loop;
                memory_address := std_logic_vector(to_unsigned(words_per_line*bus_bytes_per_word, memory_address'length));
                read_from_address(net, memActor, memory_address, memory_words);
                for i in 0 to words_per_line - 1 loop
                    check_equal(memory_words(i), std_logic_vector(to_unsigned(i + 15, memory_words(i)'length)));
                end loop;
            elsif run("After faulty write, word_index is 0") then
                write_address <= std_logic_vector(to_unsigned(2**10 - bus_bytes_per_word, write_address'length));
                write_data <= std_logic_vector(to_unsigned(0, write_data'length));
                do_write <= true;
                wait until rising_edge(clk);
                do_write <= false;
                wait until rising_edge(clk) and word_index = 1;
                write_data <= std_logic_vector(to_unsigned(1, write_data'length));
                wait until rising_edge(clk) and bus_fault;
                wait until rising_edge(clk);
                check_equal(word_index, 0);
            elsif run("Do read") then
                for i in 0 to words_per_line - 1 loop
                    memory_words(i) := std_logic_vector(to_unsigned(i, memory_words(i)'length));
                end loop;
                memory_address := std_logic_vector(to_unsigned(2 * words_per_line * bus_bytes_per_word, memory_address'length));
                memory_mask := (others => '1');
                write_to_address(net, memActor, memory_address, memory_words, memory_mask);

                read_address <= std_logic_vector(to_unsigned(2 * words_per_line * bus_bytes_per_word, read_address'length));
                do_read <= true;
                wait until rising_edge(clk);
                do_read <= false;
                for i in 0 to words_per_line - 1 loop
                    wait until rising_edge(clk) and read_word_retrieved;
                    check_equal(read_data, std_logic_vector(to_unsigned(i, read_data'length)));
                    check_equal(word_index, i);
                end loop;
                wait until rising_edge(clk) and line_complete;
            elsif run("Test fault read response") then
                read_address <= std_logic_vector(to_unsigned(2**10, read_address'length));
                do_read <= true;
                wait until rising_edge(clk);
                do_read <= false;
                wait until rising_edge(clk) and bus_fault;
                check_equal(bus_fault_data, bus_fault_address_out_of_range);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  10 us);

    cache_backend : entity src.bus_cache_backend
    generic map (
        words_per_line_log2b => words_per_line_log2b
    ) port map (
        clk => clk,
        rst => rst,
        backend2slv => backend2slv,
        slv2backend => slv2backend,
        word_index => word_index,
        do_write => do_write,
        write_address => write_address,
        write_data => write_data,
        do_read => do_read,
        read_word_retrieved => read_word_retrieved,
        read_address => read_address,
        read_data => read_data,
        line_complete => line_complete,
        bus_fault => bus_fault,
        bus_fault_data => bus_fault_data
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
