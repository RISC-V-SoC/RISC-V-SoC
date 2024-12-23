library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg.all;

entity bus_cache_director_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of bus_cache_director_tb is
    constant clk_period : time := 20 ns;
    constant words_per_line_log2b : natural := 1;
    constant total_line_count_log2b : natural := 3;
    constant bank_count_log2b : natural := 2;

    constant words_per_line : natural := 2**words_per_line_log2b;
    constant total_line_count : natural := 2**total_line_count_log2b;
    constant bank_count : natural := 2**bank_count_log2b;

    signal clk : std_logic := '0';
    signal rst : boolean := false;

    signal address : bus_aligned_address_type := (others => '0');
    signal line_index : natural := 0;
    signal index_mode : boolean := false;

    signal word_index_from_frontend : natural := 0;
    signal data_from_frontend : bus_data_type := (others => '0');
    signal bytemask_from_frontend : bus_byte_mask_type := (others => '0');
    signal data_to_frontend : bus_data_type;
    signal do_write_from_frontend : boolean := false;
    signal do_read_from_frontend : boolean := false;

    signal word_index_from_backend : natural := 0;
    signal data_from_backend : bus_data_type := (others => '0');
    signal data_to_backend : bus_data_type;
    signal do_write_from_backend : boolean := false;
    signal mark_line_clean : boolean := false;

    signal reconstructed_address : bus_aligned_address_type;

    signal hit : boolean;
    signal dirty : boolean;
begin
    clk <= not clk after (clk_period/2);

    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Simulate read on invalid line") then
                address <= std_logic_vector(to_unsigned(words_per_line * 0, address'length));
                word_index_from_frontend <= 0;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_false(hit);
                check_false(dirty);
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i, data_from_backend'length));
                    do_write_from_backend <= true;
                    if i = words_per_line-1 then
                        mark_line_clean <= true;
                    end if;
                    wait until rising_edge(clk);
                    mark_line_clean <= false;
                end loop;
                do_write_from_backend <= false;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_true(hit);
                check(or_reduce(data_to_frontend) = '0');
                do_read_from_frontend <= true;
                wait until rising_edge(clk);
                do_read_from_frontend <= false;
                wait until rising_edge(clk);
            elsif run("Cache two colliding lines") then
                address <= std_logic_vector(to_unsigned(0, address'length));
                word_index_from_frontend <= 0;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_false(hit);
                check_false(dirty);
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i, data_from_backend'length));
                    do_write_from_backend <= true;
                    if i = words_per_line-1 then
                        mark_line_clean <= true;
                    end if;
                    wait until rising_edge(clk);
                    mark_line_clean <= false;
                end loop;
                do_write_from_backend <= false;
                wait until rising_edge(clk);
                do_read_from_frontend <= true;
                word_index_from_frontend <= 0;
                wait until rising_edge(clk);
                do_read_from_frontend <= false;
                address <= std_logic_vector(to_unsigned(total_line_count * words_per_line, address'length));
                word_index_from_frontend <= 0;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_false(hit);
                check_false(dirty);
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i + 4, data_from_backend'length));
                    do_write_from_backend <= true;
                    if i = words_per_line-1 then
                        mark_line_clean <= true;
                    end if;
                    wait until rising_edge(clk);
                    mark_line_clean <= false;
                end loop;
                do_write_from_backend <= false;
                address <= std_logic_vector(to_unsigned(0, address'length));
                word_index_from_frontend <= 0;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_true(hit);
                check(or_reduce(data_to_frontend) = '0');
            elsif run("Oldest line is evicted first") then
                for bank_index in 0 to bank_count - 1 loop
                    address <= std_logic_vector(to_unsigned((bank_count * words_per_line)*bank_index, address'length));
                    wait until rising_edge(clk);
                    for i in 0 to words_per_line-1 loop
                        word_index_from_backend <= i;
                        data_from_backend <= std_logic_vector(to_unsigned(i + (bank_index * bank_count), data_from_backend'length));
                        do_write_from_backend <= true;
                        if i = words_per_line-1 then
                            mark_line_clean <= true;
                        end if;
                        wait until rising_edge(clk);
                        mark_line_clean <= false;
                    end loop;
                    do_write_from_backend <= false;
                    wait until rising_edge(clk);
                    wait until rising_edge(clk);
                    word_index_from_frontend <= 0;
                    do_read_from_frontend <= true;
                    wait until rising_edge(clk);
                    do_read_from_frontend <= false;
                end loop;
                address <= std_logic_vector(to_unsigned((bank_count * words_per_line)*bank_count, address'length));
                wait until rising_edge(clk);
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i + (bank_count * bank_count), data_from_backend'length));
                    do_write_from_backend <= true;
                    wait until rising_edge(clk);
                end loop;
                do_write_from_backend <= false;
                address <= std_logic_vector(to_unsigned(0, address'length));
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_false(hit);
            elsif run("Write also ages bank") then
                for bank_index in 0 to bank_count - 1 loop
                    address <= std_logic_vector(to_unsigned((bank_count * words_per_line)*bank_index, address'length));
                    wait until rising_edge(clk);
                    for i in 0 to words_per_line-1 loop
                        word_index_from_backend <= i;
                        data_from_backend <= std_logic_vector(to_unsigned(i + (bank_index * bank_count), data_from_backend'length));
                        do_write_from_backend <= true;
                        if i = words_per_line-1 then
                            mark_line_clean <= true;
                        end if;
                        wait until rising_edge(clk);
                    end loop;
                    do_write_from_backend <= false;
                    wait until rising_edge(clk);
                    word_index_from_frontend <= 0;
                    do_write_from_frontend <= true;
                    data_from_frontend <= std_logic_vector(to_unsigned(0, data_from_frontend'length));
                    wait until rising_edge(clk);
                    do_write_from_frontend <= false;
                end loop;
                address <= std_logic_vector(to_unsigned((bank_count * words_per_line)*bank_count, address'length));
                wait until rising_edge(clk);
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i + (bank_count * bank_count), data_from_backend'length));
                    do_write_from_backend <= true;
                    wait until rising_edge(clk);
                end loop;
                do_write_from_backend <= false;
                address <= std_logic_vector(to_unsigned(0, address'length));
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_false(hit);
            elsif run("Test index mode") then
                for index in 0 to total_line_count - 1 loop
                    address <= std_logic_vector(to_unsigned(index * words_per_line, address'length));
                    wait until rising_edge(clk);
                    for i in 0 to words_per_line-1 loop
                        word_index_from_backend <= i;
                        data_from_backend <= std_logic_vector(to_unsigned(index, data_from_backend'length));
                        do_write_from_backend <= true;
                        if i = words_per_line-1 then
                            mark_line_clean <= true;
                        end if;
                        wait until rising_edge(clk);
                        mark_line_clean <= false;
                    end loop;
                    do_write_from_backend <= false;
                    wait until rising_edge(clk);
                    wait until rising_edge(clk);
                    word_index_from_frontend <= 0;
                    do_read_from_frontend <= index rem 2 = 0;
                    do_write_from_frontend <= index rem 2 /= 0;
                    data_from_frontend <= std_logic_vector(to_unsigned(1000 + index, data_from_frontend'length));
                    bytemask_from_frontend <= (others => '1');
                    wait until rising_edge(clk);
                    do_read_from_frontend <= false;
                    do_write_from_frontend <= false;
                end loop;
                wait until rising_edge(clk);
                index_mode <= true;
                word_index_from_backend <= 0;
                for index in 0 to total_line_count - 1 loop
                    line_index <= index;
                    wait until rising_edge(clk);
                    wait until falling_edge(clk);
                    check_equal(reconstructed_address, std_logic_vector(to_unsigned(index * words_per_line, reconstructed_address'length)));
                    check(dirty = (index rem 2 /= 0));
                    if index rem 2 = 0 then
                        check_equal(data_to_backend, std_logic_vector(to_unsigned(index, data_to_frontend'length)));
                    else
                        check_equal(data_to_backend, std_logic_vector(to_unsigned(1000 + index, data_to_frontend'length)));
                    end if;
                end loop;
            elsif run("Lines older than the current line do not age") then
                for bank_index in 0 to 1 loop
                    address <= std_logic_vector(to_unsigned((bank_count * words_per_line)*bank_index, address'length));
                    wait until rising_edge(clk);
                    for i in 0 to words_per_line-1 loop
                        word_index_from_backend <= i;
                        data_from_backend <= std_logic_vector(to_unsigned(i + (bank_index * bank_count), data_from_backend'length));
                        do_write_from_backend <= true;
                        if i = words_per_line-1 then
                            mark_line_clean <= true;
                        end if;
                        wait until rising_edge(clk);
                        mark_line_clean <= false;
                    end loop;
                    do_write_from_backend <= false;
                    wait until rising_edge(clk);
                    wait until rising_edge(clk);
                    word_index_from_frontend <= 0;
                    do_read_from_frontend <= true;
                    wait until rising_edge(clk);
                    do_read_from_frontend <= false;
                end loop;
                wait until rising_edge(clk);
                for i in 0 to 5 loop
                do_read_from_frontend <= true;
                wait until rising_edge(clk);
                do_read_from_frontend <= false;
                end loop;

                for bank_index in 2 to bank_count - 1 loop
                    address <= std_logic_vector(to_unsigned((bank_count * words_per_line)*bank_index, address'length));
                    wait until rising_edge(clk);
                    for i in 0 to words_per_line-1 loop
                        word_index_from_backend <= i;
                        data_from_backend <= std_logic_vector(to_unsigned(i + (bank_index * bank_count), data_from_backend'length));
                        do_write_from_backend <= true;
                        if i = words_per_line-1 then
                            mark_line_clean <= true;
                        end if;
                        wait until rising_edge(clk);
                        mark_line_clean <= false;
                    end loop;
                    do_write_from_backend <= false;
                    wait until rising_edge(clk);
                    word_index_from_frontend <= 0;
                    do_read_from_frontend <= true;
                    wait until rising_edge(clk);
                    do_read_from_frontend <= false;
                end loop;

                address <= std_logic_vector(to_unsigned(words_per_line * 0, address'length));
                word_index_from_frontend <= 0;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_true(hit);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  10 us);

    cache_director : entity src.bus_cache_director
    generic map (
        words_per_line_log2b => words_per_line_log2b,
        total_line_count_log2b => total_line_count_log2b,
        bank_count_log2b => bank_count_log2b
    ) port map (
        clk => clk,
        rst => rst,
        address => address,
        line_index => line_index,
        index_mode => index_mode,
        word_index_from_frontend => word_index_from_frontend,
        data_from_frontend => data_from_frontend,
        bytemask_from_frontend => bytemask_from_frontend,
        data_to_frontend => data_to_frontend,
        do_write_from_frontend => do_write_from_frontend,
        do_read_from_frontend => do_read_from_frontend,
        word_index_from_backend => word_index_from_backend,
        data_from_backend => data_from_backend,
        data_to_backend => data_to_backend,
        do_write_from_backend => do_write_from_backend,
        mark_line_clean => mark_line_clean,
        reconstructed_address => reconstructed_address,
        hit => hit,
        dirty => dirty
    );
end architecture;
