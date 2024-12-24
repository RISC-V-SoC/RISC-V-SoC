library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg.all;

entity bus_cache_bank_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of bus_cache_bank_tb is
    constant clk_period : time := 20 ns;

    constant words_per_line_log2b : natural := 2;
    constant words_per_line : natural := 2**words_per_line_log2b;
    constant line_count_log2b : natural := 2;
    constant line_count : natural := 2**line_count_log2b;
    constant max_age : natural := 3;

    signal clk : std_logic := '0';
    signal rst : boolean := false;

    signal address : bus_aligned_address_type := (others => '0');
    signal line_index : natural range 0 to line_count-1 := 0;

    signal index_mode : boolean := false;
    signal word_index_from_frontend : natural range 0 to words_per_line-1 := 0;
    signal data_from_frontend : bus_data_type := (others => '0');
    signal bytemask_from_frontend : bus_byte_mask_type := (others => '1');
    signal data_to_frontend : bus_data_type;
    signal do_write_from_frontend : boolean;

    signal word_index_from_backend : natural range 0 to words_per_line-1 := 0;
    signal data_from_backend : bus_data_type := (others => '0');
    signal data_to_backend : bus_data_type;
    signal do_write_from_backend : boolean;
    signal mark_line_clean : boolean;

    signal reset_age : boolean := false;
    signal increase_age : boolean := false;

    signal miss : boolean;
    signal dirty : boolean;
    signal age : natural range 0 to max_age;
    signal reconstructed_address : bus_aligned_address_type;
begin

    clk <= not clk after (clk_period/2);

    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Invalid line causes miss") then
                address <= (others => '0');
                wait until rising_edge(clk);
                check(miss);
            elsif run("Valid line does not cause miss") then
                address <= (others => '0');
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i, data_from_backend'length));
                    do_write_from_backend <= true;
                    if i = words_per_line - 1 then
                        mark_line_clean <= true;
                    end if;
                    wait until rising_edge(clk);
                    mark_line_clean <= false;
                end loop;
                do_write_from_backend <= false;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check(not miss);
            elsif run("Directly after a backend line write, the age of the line is max_age") then
                address <= (others => '0');
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i, data_from_backend'length));
                    do_write_from_backend <= true;
                    if i = words_per_line - 1 then
                        mark_line_clean <= true;
                    end if;
                    wait until rising_edge(clk);
                    mark_line_clean <= false;
                end loop;
                do_write_from_backend <= false;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check(age = max_age);
            elsif run("Partial line write still misses") then
                address <= (others => '0');
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i, data_from_backend'length));
                    do_write_from_backend <= true;
                    if i = words_per_line - 1 then
                        mark_line_clean <= true;
                    end if;
                    wait until rising_edge(clk);
                    mark_line_clean <= false;
                end loop;
                do_write_from_backend <= false;
                wait until rising_edge(clk);
                address <= std_logic_vector(to_unsigned(words_per_line * line_count, address'length));
                word_index_from_backend <= 0;
                wait until rising_edge(clk);
                data_from_backend <= std_logic_vector(to_unsigned(0, data_from_backend'length));
                do_write_from_backend <= true;
                wait until rising_edge(clk);
                do_write_from_backend <= false;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check(miss);
            elsif run("Read line trough backend") then
                address <= (others => '0');
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i, data_from_backend'length));
                    do_write_from_backend <= true;
                    if i = words_per_line - 1 then
                        mark_line_clean <= true;
                    end if;
                    wait until rising_edge(clk);
                    mark_line_clean <= false;
                end loop;
                do_write_from_backend <= false;
                wait until falling_edge(clk);
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    wait until falling_edge(clk);
                    check_equal(data_to_backend, std_logic_vector(to_unsigned(i, data_from_backend'length)));
                end loop;
            elsif run("Read line trough frontend") then
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i, data_from_backend'length));
                    do_write_from_backend <= true;
                    if i = words_per_line - 1 then
                        mark_line_clean <= true;
                    end if;
                    wait until rising_edge(clk);
                    mark_line_clean <= false;
                end loop;
                do_write_from_backend <= false;
                wait until falling_edge(clk);
                for i in 0 to words_per_line-1 loop
                    word_index_from_frontend <= i;
                    wait until falling_edge(clk);
                    check_equal(data_to_frontend, std_logic_vector(to_unsigned(i, data_from_frontend'length)));
                end loop;
            elsif run("Test write trough frontend") then
                address <= (others => '0');
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i, data_from_backend'length));
                    do_write_from_backend <= true;
                    if i = words_per_line - 1 then
                        mark_line_clean <= true;
                    end if;
                    wait until rising_edge(clk);
                    mark_line_clean <= false;
                end loop;
                do_write_from_backend <= false;
                word_index_from_frontend <= 0;
                data_from_frontend <= (others => '1');
                bytemask_from_frontend <= (others => '1');
                do_write_from_frontend <= true;
                wait until rising_edge(clk);
                do_write_from_frontend <= false;
                wait until falling_edge(clk);
                wait until falling_edge(clk);
                check(or_reduce(data_to_frontend) = '1');
            elsif run("After backend write, a line is clean") then
                address <= (others => '0');
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i, data_from_backend'length));
                    do_write_from_backend <= true;
                    if i = words_per_line - 1 then
                        mark_line_clean <= true;
                    end if;
                    wait until rising_edge(clk);
                    mark_line_clean <= false;
                end loop;
                wait until falling_edge(clk);
                wait until falling_edge(clk);
                check(not dirty);
            elsif run("After a frondend write, a line is dirty") then
                address <= (others => '0');
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i, data_from_backend'length));
                    do_write_from_backend <= true;
                    if i = words_per_line - 1 then
                        mark_line_clean <= true;
                    end if;
                    wait until rising_edge(clk);
                    mark_line_clean <= false;
                end loop;
                do_write_from_backend <= false;
                wait until rising_edge(clk);
                word_index_from_frontend <= 0;
                data_from_frontend <= (others => '1');
                bytemask_from_frontend <= (others => '1');
                do_write_from_frontend <= true;
                wait until rising_edge(clk);
                do_write_from_frontend <= false;
                wait until falling_edge(clk);
                wait until falling_edge(clk);
                check(dirty);
            elsif run("After frontend then backend write, a line is clean") then
                address <= (others => '0');
                word_index_from_frontend <= 0;
                data_from_frontend <= (others => '1');
                bytemask_from_frontend <= (others => '1');
                do_write_from_frontend <= true;
                wait until rising_edge(clk);
                do_write_from_frontend <= false;
                wait until rising_edge(clk);
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i, data_from_backend'length));
                    do_write_from_backend <= true;
                    if i = words_per_line - 1 then
                        mark_line_clean <= true;
                    end if;
                    wait until rising_edge(clk);
                    mark_line_clean <= false;
                end loop;
                wait until falling_edge(clk);
                wait until falling_edge(clk);
                check(not dirty);
            elsif run("Frontend bytemask is respected") then
                address <= (others => '0');
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i, data_from_backend'length));
                    do_write_from_backend <= true;
                    if i = words_per_line - 1 then
                        mark_line_clean <= true;
                    end if;
                    wait until rising_edge(clk);
                    mark_line_clean <= false;
                end loop;
                wait until rising_edge(clk);
                word_index_from_frontend <= 0;
                data_from_frontend <= (others => '1');
                bytemask_from_frontend <= (others => '0');
                do_write_from_frontend <= true;
                wait until rising_edge(clk);
                do_write_from_frontend <= false;
                wait until falling_edge(clk);
                wait until falling_edge(clk);
                check(or_reduce(data_to_frontend) = '0');
            elsif run("After a reset, no line is dirty") then
                address <= (others => '0');
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i, data_from_backend'length));
                    do_write_from_backend <= true;
                    if i = words_per_line - 1 then
                        mark_line_clean <= true;
                    end if;
                    wait until rising_edge(clk);
                    mark_line_clean <= false;
                end loop;
                do_write_from_backend <= false;
                wait until rising_edge(clk);
                word_index_from_frontend <= 0;
                data_from_frontend <= (others => '1');
                bytemask_from_frontend <= (others => '1');
                do_write_from_frontend <= true;
                wait until rising_edge(clk);
                do_write_from_frontend <= false;
                wait until rising_edge(clk);
                rst <= true;
                wait until rising_edge(clk);
                rst <= false;
                wait until falling_edge(clk);
                wait until falling_edge(clk);
                check(not dirty);
            elsif run("Line will miss if it points to different address") then
                address <= (others => '0');
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i, data_from_backend'length));
                    do_write_from_backend <= true;
                    if i = words_per_line - 1 then
                        mark_line_clean <= true;
                    end if;
                    wait until rising_edge(clk);
                    mark_line_clean <= false;
                end loop;
                do_write_from_backend <= false;
                wait until rising_edge(clk);
                address <= std_logic_vector(to_unsigned(words_per_line * line_count, address'length));
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check(miss);
            elsif run("Reconstructed address is correct") then
                address <= std_logic_vector(to_unsigned(words_per_line * line_count, address'length));
                wait until rising_edge(clk);
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i, data_from_backend'length));
                    do_write_from_backend <= true;
                    if i = words_per_line - 1 then
                        mark_line_clean <= true;
                    end if;
                    wait until rising_edge(clk);
                    mark_line_clean <= false;
                end loop;
                do_write_from_backend <= false;
                address <= (others => '0');
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(reconstructed_address, std_logic_vector(to_unsigned(words_per_line * line_count, reconstructed_address'length)));
                address <= std_logic_vector(to_unsigned(words_per_line * (line_count + 1) , address'length));
                wait until rising_edge(clk);
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i, data_from_backend'length));
                    do_write_from_backend <= true;
                    wait until rising_edge(clk);
                end loop;
                do_write_from_backend <= false;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(reconstructed_address, std_logic_vector(to_unsigned(words_per_line * (line_count + 1), reconstructed_address'length)));
            elsif run("The age of an invalid line is always max_age") then
                address <= (others => '0');
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(age, max_age);
            elsif run("Increase age") then
                address <= (others => '0');
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i, data_from_backend'length));
                    do_write_from_backend <= true;
                    if i = words_per_line - 1 then
                        mark_line_clean <= true;
                    end if;
                    wait until rising_edge(clk);
                    mark_line_clean <= false;
                end loop;
                do_write_from_backend <= false;
                wait until rising_edge(clk) and age = max_age;
                reset_age <= true;
                wait until rising_edge(clk);
                reset_age <= false;
                wait until rising_edge(clk) and age = 0;
                increase_age <= true;
                wait until rising_edge(clk);
                increase_age <= false;
                wait until rising_edge(clk) and age = 1;
            elsif run("Age saturates") then
                address <= (others => '0');
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i, data_from_backend'length));
                    do_write_from_backend <= true;
                    if i = words_per_line - 1 then
                        mark_line_clean <= true;
                    end if;
                    wait until rising_edge(clk);
                    mark_line_clean <= false;
                end loop;
                do_write_from_backend <= false;
                wait until rising_edge(clk);
                increase_age <= true;
                for i in 0 to max_age loop
                    wait until rising_edge(clk);
                end loop;
                increase_age <= false;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(age, max_age);
            elsif run("Reset age") then
                address <= (others => '0');
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i, data_from_backend'length));
                    do_write_from_backend <= true;
                    if i = words_per_line - 1 then
                        mark_line_clean <= true;
                    end if;
                    wait until rising_edge(clk);
                    mark_line_clean <= false;
                end loop;
                do_write_from_backend <= false;
                wait until rising_edge(clk);
                increase_age <= true;
                wait until rising_edge(clk);
                increase_age <= false;
                reset_age <= true;
                wait until rising_edge(clk);
                reset_age <= false;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(age, 0);
            elsif run("Test index mode") then
                address <= std_logic_vector(to_unsigned(words_per_line * 1, address'length));
                wait until rising_edge(clk);
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i, data_from_backend'length));
                    do_write_from_backend <= true;
                    if i = words_per_line - 1 then
                        mark_line_clean <= true;
                    end if;
                    wait until rising_edge(clk);
                    mark_line_clean <= false;
                end loop;
                address <= std_logic_vector(to_unsigned(words_per_line * 2, address'length));
                wait until rising_edge(clk);
                for i in 0 to words_per_line-1 loop
                    word_index_from_backend <= i;
                    data_from_backend <= std_logic_vector(to_unsigned(i, data_from_backend'length));
                    do_write_from_backend <= true;
                    if i = words_per_line - 1 then
                        mark_line_clean <= true;
                    end if;
                    wait until rising_edge(clk);
                    mark_line_clean <= false;
                end loop;
                do_write_from_backend <= false;
                wait until rising_edge(clk);
                word_index_from_frontend <= 0;
                data_from_frontend <= (others => '1');
                bytemask_from_frontend <= (others => '1');
                do_write_from_frontend <= true;
                wait until rising_edge(clk);
                do_write_from_frontend <= false;
                address <= std_logic_vector(to_unsigned(words_per_line * 3, address'length));
                wait until rising_edge(clk);
                index_mode <= true;
                line_index <= 1;
                for i in 0 to words_per_line - 1 loop
                    word_index_from_frontend <= i;
                    wait until rising_edge(clk);
                    wait until falling_edge(clk);
                    check_equal(reconstructed_address, std_logic_vector(to_unsigned(words_per_line * 1, reconstructed_address'length)));
                    check_false(dirty);
                    check_equal(data_to_frontend, std_logic_vector(to_unsigned(i, data_to_frontend'length)));
                end loop;
                line_index <= 2;
                word_index_from_backend <= 0;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(reconstructed_address, std_logic_vector(to_unsigned(words_per_line * 2, reconstructed_address'length)));
                check_true(dirty);
                check(and_reduce(data_to_backend) = '1');
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 us);

    cache_bank : entity src.bus_cache_bank
    generic map (
        words_per_line_log2b => words_per_line_log2b,
        line_count_log2b => line_count_log2b,
        max_age => max_age
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

        word_index_from_backend => word_index_from_backend,
        data_from_backend => data_from_backend,
        data_to_backend => data_to_backend,
        do_write_from_backend => do_write_from_backend,
        mark_line_clean => mark_line_clean,

        reset_age => reset_age,
        increase_age => increase_age,

        miss => miss,
        dirty => dirty,
        age => age,
        reconstructed_address => reconstructed_address
    );

end architecture;
