library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg.all;

entity bus_cache_flusher_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of bus_cache_flusher_tb is
    constant clk_period : time := 20 ns;
    constant total_line_count_log2b : natural := 3;
    constant total_line_count : natural := 2**total_line_count_log2b;

    signal clk : std_logic := '0';
    signal rst : boolean := false;

    signal do_flush : boolean := false;
    signal flush_busy : boolean;

    signal line_index : natural range 0 to 2**total_line_count_log2b - 1;
    signal cache_read_busy : boolean := false;
    signal is_dirty : boolean := false;
    signal do_write : boolean;
    signal write_complete : boolean := false;

    signal reset_cache : boolean;
begin
    clk <= not clk after (clk_period/2);

    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("After do_flush, flush_busy rises") then
                do_flush <= true;
                wait until rising_edge(clk) and flush_busy;
            elsif run("Initially, flush_busy is false") then
                check_false(flush_busy);
            elsif run("Full run where no line is dirty") then
                do_flush <= true;
                wait until rising_edge(clk) and flush_busy;
                for i in 0 to total_line_count - 1 loop
                    wait until rising_edge(clk) and line_index = i;
                    check_false(do_write);
                    wait until rising_edge(clk);
                    check_equal(line_index, i);
                    check_false(do_write);
                    is_dirty <= false;
                end loop;
                wait until rising_edge(clk) and reset_cache;
                wait until rising_edge(clk) and not flush_busy;
                check_false(reset_cache);
            elsif run("Line 0 is dirty") then
                do_flush <= true;
                wait until rising_edge(clk) and flush_busy;
                wait until rising_edge(clk);
                check_equal(line_index, 0);
                check_false(do_write);
                cache_read_busy <= true;
                wait for 5*clk_period;
                check_false(do_write);
                cache_read_busy <= false;
                is_dirty <= true;
                wait until rising_edge(clk) and do_write;
                check_equal(line_index, 0);
                wait until rising_edge(clk);
                check_false(do_write);
                wait for 5*clk_period;
                write_complete <= true;
                wait for clk_period;
                write_complete <= false;
            elsif run("Last line is dirty") then
                do_flush <= true;
                wait until rising_edge(clk) and flush_busy;
                for i in 0 to total_line_count - 2 loop
                    wait until rising_edge(clk) and line_index = i;
                    check_false(do_write);
                    wait until rising_edge(clk);
                    check_equal(line_index, i);
                    check_false(do_write);
                    is_dirty <= false;
                end loop;
                wait until rising_edge(clk) and line_index = total_line_count - 1;
                check_false(do_write);
                is_dirty <= true;
                wait until rising_edge(clk) and do_write;
                check_equal(line_index, total_line_count - 1);
                wait until rising_edge(clk);
                check_false(do_write);
                wait for 5*clk_period;
                write_complete <= true;
                wait for clk_period;
                write_complete <= false;
                wait until rising_edge(clk) and reset_cache;
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  10 us);

    cache_flusher : entity src.bus_cache_flusher
    generic map (
        total_line_count_log2b => total_line_count_log2b
    ) port map (
        clk => clk,
        rst => rst,
        do_flush => do_flush,
        flush_busy => flush_busy,
        line_index => line_index,
        cache_read_busy => cache_read_busy,
        is_dirty => is_dirty,
        do_write => do_write,
        write_complete => write_complete,
        reset_cache => reset_cache
    );
end architecture;
