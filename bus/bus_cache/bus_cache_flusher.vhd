library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;

entity bus_cache_flusher is
    generic (
        total_line_count_log2b : natural range 1 to natural'high
    );
    port (
        clk : in std_logic;
        rst : in boolean;

        do_flush : in boolean;
        flush_busy : out boolean;

        line_index : out natural range 0 to 2**total_line_count_log2b - 1;
        is_dirty : in boolean;
        do_write : out boolean;
        write_complete : in boolean;

        reset_cache : out boolean
    );
end entity;

architecture behaviourial of bus_cache_flusher is
    type state_type is (idle, start, request_from_cache, process_response, initiate_write, wait_for_write, finish);

    constant line_index_max : natural := 2**total_line_count_log2b - 1;

    signal cur_state : state_type := idle;
    signal next_state : state_type := idle;

    signal line_index_buf : natural range 0 to 2**total_line_count_log2b - 1 := 0;
begin

    line_index <= line_index_buf;

    line_index_counter : process(clk)
    begin
        if rising_edge(clk) then
            if rst or cur_state = idle then
                line_index_buf <= 0;
            elsif cur_state /= start and next_state = request_from_cache then
                line_index_buf <= line_index_buf + 1;
            end if;
        end if;
    end process;

    state_decider : process(clk, do_flush, line_index_buf, is_dirty)
    begin
        if rising_edge(clk) then
            if rst then
                cur_state <= idle;
            else
                cur_state <= next_state;
            end if;
        end if;

        next_state <= cur_state;

        case cur_state is
            when idle =>
                if do_flush then
                    next_state <= start;
                end if;
            when start =>
                next_state <= request_from_cache;
            when request_from_cache =>
                next_state <= process_response;
            when process_response =>
                if is_dirty then
                    next_state <= initiate_write;
                elsif line_index_buf = line_index_max then
                    next_state <= finish;
                else
                    next_state <= request_from_cache;
                end if;
            when initiate_write =>
                next_state <= wait_for_write;
            when wait_for_write =>
                if write_complete then
                    if line_index_buf = line_index_max then
                        next_state <= finish;
                    else
                        next_state <= request_from_cache;
                    end if;
                end if;
            when finish =>
                next_state <= idle;
        end case;
    end process;

    state_output : process(cur_state)
    begin
        case cur_state is
            when idle =>
                flush_busy <= false;
                do_write <= false;
                reset_cache <= false;
            when start =>
                flush_busy <= true;
                do_write <= false;
                reset_cache <= false;
            when request_from_cache =>
                flush_busy <= true;
                do_write <= false;
                reset_cache <= false;
            when process_response =>
                flush_busy <= true;
                do_write <= false;
                reset_cache <= false;
            when initiate_write =>
                flush_busy <= true;
                do_write <= true;
                reset_cache <= false;
            when wait_for_write =>
                flush_busy <= true;
                do_write <= false;
                reset_cache <= false;
            when finish =>
                flush_busy <= true;
                do_write <= false;
                reset_cache <= true;
        end case;
    end process;
end architecture;
