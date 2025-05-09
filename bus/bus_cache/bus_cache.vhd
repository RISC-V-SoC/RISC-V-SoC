library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.bus_pkg.all;

entity bus_cache is
    generic (
        words_per_line_log2b : natural range 0 to natural'high;
        total_line_count_log2b : natural range 1 to natural'high;
        bank_count_log2b : natural range 1 to natural'high
    );
    port (
        clk : in std_logic;
        rst : in boolean;

        mst2frontend : in bus_mst2slv_type;
        frontend2mst : out bus_slv2mst_type;

        backend2slv : out bus_mst2slv_type;
        slv2backend : in bus_slv2mst_type;

        do_flush : in boolean;
        flush_busy : out boolean
    );
end entity;

architecture behaviourial of bus_cache is
    constant word_index_lsb : natural := bus_bytes_per_word_log2b;
    constant word_index_msb : natural := word_index_lsb + words_per_line_log2b - 1;
    constant truncated_address_lsb : natural := word_index_msb + 1;
    type state_type is (idle, wait_for_cache, wait_for_cache_II, wait_for_cache_III, process_cache_response, bytemask_fault_detected, update_cache, dirty_word_to_backend, wait_for_backend_write, request_from_backend, wait_for_backend_read, flusher_start, flusher_active);

    signal cur_state : state_type := idle;
    signal next_state : state_type := idle;

    signal cache_line_index : natural range 0 to 2**total_line_count_log2b - 1;
    signal cache_index_mode : boolean;
    signal cache_mark_line_clean : boolean;
    signal cache_input_address : bus_aligned_address_type;
    signal cache_reconstructed_address : bus_aligned_address_type;
    signal cache_do_read : boolean;
    signal cache_do_write : boolean;
    signal cache_hit : boolean;
    signal cache_dirty : boolean;
    signal cache_frontend_read_data : bus_data_type;
    signal cache_frontend_write_data : bus_data_type;
    signal cache_frontend_bytemask : bus_byte_mask_type;

    signal frontend_address : bus_address_type;
    signal frontend_word_index : natural range 0 to 2**words_per_line_log2b - 1;
    signal frontend_write_data : bus_data_type;
    signal frontend_bytemask : bus_byte_mask_type;
    signal frontend_read_data : bus_data_type;
    signal frontend_requests_write : boolean;
    signal frontend_requests_read : boolean;
    signal frontend_complete_transaction : boolean;
    signal frontend_fault_transaction : boolean;
    signal frontend_fault_data : bus_fault_type;

    signal backend_word_index : natural range 0 to 2**words_per_line_log2b - 1;
    signal backend_write_data : bus_data_type;
    signal backend_read_data : bus_data_type;
    signal backend_do_write : boolean;
    signal backend_do_read : boolean;
    signal backend_word_read_complete : boolean;
    signal backend_line_operation_complete : boolean;
    signal backend_bus_fault : boolean;
    signal backend_bus_fault_data : bus_fault_type;

    signal bytemask_fault : boolean;

    signal flusher_do_flush : boolean;
    signal flusher_flush_busy : boolean;
    signal flusher_do_write : boolean;
    signal flusher_reset_cache : boolean;
begin
    cache_index_mode <= flusher_flush_busy;
    data_shifter : process(frontend_address, cache_frontend_read_data, frontend_write_data, frontend_bytemask)
        constant shift_index_lsb : natural := 0;
        constant shift_index_msb : natural := word_index_lsb - 1;

        variable bytes_to_shift : natural range 0 to bus_bytes_per_word - 1;
    begin
        bytes_to_shift := to_integer(unsigned(frontend_address(shift_index_msb downto shift_index_lsb)));
        frontend_read_data <= std_logic_vector(shift_right(unsigned(cache_frontend_read_data), bytes_to_shift * bus_byte_size));
        cache_frontend_write_data <=
            std_logic_vector(shift_left(unsigned(frontend_write_data), bytes_to_shift * bus_byte_size));
        cache_frontend_bytemask <= std_logic_vector(shift_left(unsigned(frontend_bytemask), bytes_to_shift));

        bytemask_fault <=
            or_reduce(frontend_bytemask(frontend_bytemask'high downto frontend_bytemask'length - bytes_to_shift)) /= '0';
    end process;

    determine_cache_input : process(frontend_address)
    begin
        cache_input_address <= (others => '0');
        cache_input_address(cache_input_address'high downto truncated_address_lsb) <=
            frontend_address(frontend_address'high downto truncated_address_lsb);
        frontend_word_index <= to_integer(unsigned(frontend_address(word_index_msb downto word_index_lsb)));
    end process;

    determine_fault_data : process(backend_bus_fault, backend_bus_fault_data)
    begin
        if backend_bus_fault then
            frontend_fault_data <= backend_bus_fault_data;
        else
            frontend_fault_data <= bus_fault_illegal_byte_mask;
        end if;
    end process;

    cur_state_handling : process(clk)
    begin
        if rising_edge(clk) then
            if rst then
                cur_state <= idle;
            else
                cur_state <= next_state;
            end if;
        end if;
    end process;

    next_state_handling : process(cur_state, cache_hit, cache_dirty, frontend_requests_write, frontend_requests_read, backend_line_operation_complete, backend_bus_fault, bytemask_fault, flusher_flush_busy, do_flush)
    begin
        next_state <= cur_state;
        case cur_state is
            when idle =>
                if frontend_requests_read or frontend_requests_write then
                    next_state <= wait_for_cache;
                elsif do_flush then
                    next_state <= flusher_start;
                end if;
            when wait_for_cache =>
                next_state <= wait_for_cache_II;
            when wait_for_cache_II =>
                next_state <= wait_for_cache_III;
            when wait_for_cache_III =>
                next_state <= process_cache_response;
            when process_cache_response =>
                if bytemask_fault then
                    next_state <= bytemask_fault_detected;
                elsif cache_hit then
                    next_state <= update_cache;
                elsif cache_dirty then
                    next_state <= dirty_word_to_backend;
                else
                    next_state <= request_from_backend;
                end if;
            when update_cache =>
                next_state <= idle;
            when bytemask_fault_detected =>
                next_state <= idle;
            when dirty_word_to_backend =>
                next_state <= wait_for_backend_write;
            when wait_for_backend_write =>
                if backend_bus_fault then
                    next_state <= idle;
                elsif backend_line_operation_complete then
                    next_state <= request_from_backend;
                end if;
            when request_from_backend =>
                next_state <= wait_for_backend_read;
            when wait_for_backend_read =>
                if backend_line_operation_complete or backend_bus_fault then
                    next_state <= idle;
                end if;
            when flusher_start =>
                next_state <= flusher_active;
            when flusher_active =>
                if not flusher_flush_busy then
                    next_state <= idle;
                end if;
        end case;
    end process;

    state_output : process(cur_state, backend_line_operation_complete, frontend_requests_read, frontend_requests_write, backend_bus_fault, flusher_do_write)
    begin
        case cur_state is
            when idle|wait_for_cache|wait_for_cache_II|wait_for_cache_III|process_cache_response =>
                cache_mark_line_clean <= false;
                cache_do_read <= false;
                cache_do_write <= false;
                frontend_complete_transaction <= false;
                frontend_fault_transaction <= false;
                backend_do_write <= false;
                backend_do_read <= false;
                flusher_do_flush <= false;
                flush_busy <= false;
            when update_cache =>
                cache_mark_line_clean <= false;
                cache_do_read <= frontend_requests_read;
                cache_do_write <= frontend_requests_write;
                frontend_complete_transaction <= true;
                frontend_fault_transaction <= false;
                backend_do_write <= false;
                backend_do_read <= false;
                flusher_do_flush <= false;
                flush_busy <= false;
            when bytemask_fault_detected =>
                cache_mark_line_clean <= false;
                cache_do_read <= false;
                cache_do_write <= false;
                frontend_complete_transaction <= false;
                frontend_fault_transaction <= true;
                backend_do_write <= false;
                backend_do_read <= false;
                flusher_do_flush <= false;
                flush_busy <= false;
            when dirty_word_to_backend =>
                cache_mark_line_clean <= false;
                cache_do_read <= false;
                cache_do_write <= false;
                frontend_complete_transaction <= false;
                frontend_fault_transaction <= false;
                backend_do_write <= true;
                backend_do_read <= false;
                flusher_do_flush <= false;
                flush_busy <= false;
            when wait_for_backend_write =>
                cache_mark_line_clean <= false;
                cache_do_read <= false;
                cache_do_write <= false;
                frontend_complete_transaction <= false;
                frontend_fault_transaction <= backend_bus_fault;
                backend_do_write <= false;
                backend_do_read <= false;
                flusher_do_flush <= false;
                flush_busy <= false;
            when request_from_backend =>
                cache_mark_line_clean <= false;
                cache_do_read <= false;
                cache_do_write <= false;
                frontend_complete_transaction <= false;
                frontend_fault_transaction <= false;
                backend_do_write <= false;
                backend_do_read <= true;
                flusher_do_flush <= false;
                flush_busy <= false;
            when wait_for_backend_read =>
                cache_mark_line_clean <= backend_line_operation_complete;
                cache_do_read <= false;
                cache_do_write <= false;
                frontend_complete_transaction <= false;
                frontend_fault_transaction <= backend_bus_fault;
                backend_do_write <= false;
                backend_do_read <= false;
                flusher_do_flush <= false;
                flush_busy <= false;
            when flusher_start =>
                cache_mark_line_clean <= false;
                cache_do_read <= false;
                cache_do_write <= false;
                frontend_complete_transaction <= false;
                frontend_fault_transaction <= false;
                backend_do_write <= false;
                backend_do_read <= false;
                flusher_do_flush <= true;
                flush_busy <= true;
            when flusher_active =>
                cache_mark_line_clean <= false;
                cache_do_read <= false;
                cache_do_write <= false;
                frontend_complete_transaction <= false;
                frontend_fault_transaction <= false;
                backend_do_write <= flusher_do_write;
                backend_do_read <= false;
                flusher_do_flush <= false;
                flush_busy <= true;
        end case;
    end process;

    cache_director : entity work.bus_cache_director
    generic map (
        words_per_line_log2b => words_per_line_log2b,
        total_line_count_log2b => total_line_count_log2b,
        bank_count_log2b => bank_count_log2b
    ) port map (
        clk => clk,
        rst => rst or flusher_reset_cache,
        address => cache_input_address,
        line_index => cache_line_index,
        index_mode => cache_index_mode,

        word_index_from_frontend => frontend_word_index,
        data_from_frontend => cache_frontend_write_data,
        bytemask_from_frontend => cache_frontend_bytemask,
        data_to_frontend => cache_frontend_read_data,
        do_write_from_frontend => cache_do_write,
        do_read_from_frontend => cache_do_read,

        word_index_from_backend => backend_word_index,
        data_from_backend => backend_read_data,
        data_to_backend => backend_write_data,
        do_write_from_backend => backend_word_read_complete,

        mark_line_clean => cache_mark_line_clean,
        reconstructed_address => cache_reconstructed_address,
        hit => cache_hit,
        dirty => cache_dirty
    );

    cache_frontend : entity work.bus_cache_frontend
    port map (
        clk => clk,
        rst => rst,
        mst2frontend => mst2frontend,
        frontend2mst => frontend2mst,
        address => frontend_address,
        byte_mask => frontend_bytemask,
        data_out => frontend_write_data,
        data_in => frontend_read_data,
        is_read => frontend_requests_read,
        is_write => frontend_requests_write,
        complete_transaction => frontend_complete_transaction,
        error_transaction => frontend_fault_transaction,
        fault_data => frontend_fault_data
    );

    cache_backend : entity work.bus_cache_backend
    generic map (
        words_per_line_log2b => words_per_line_log2b
    ) port map (
        clk => clk,
        rst => rst,
        backend2slv => backend2slv,
        slv2backend => slv2backend,
        word_index => backend_word_index,
        do_write => backend_do_write,
        write_address => cache_reconstructed_address & "00",
        write_data => backend_write_data,
        do_read => backend_do_read,
        read_word_retrieved => backend_word_read_complete,
        read_address => cache_input_address & "00",
        read_data => backend_read_data,
        line_complete => backend_line_operation_complete,

        bus_fault => backend_bus_fault,
        bus_fault_data => backend_bus_fault_data
    );

    cache_flusher : entity work.bus_cache_flusher
    generic map (
        total_line_count_log2b => total_line_count_log2b
    ) port map (
        clk => clk,
        rst => rst,
        do_flush => flusher_do_flush,
        flush_busy => flusher_flush_busy,
        line_index => cache_line_index,
        is_dirty => cache_dirty,
        do_write => flusher_do_write,
        write_complete => backend_line_operation_complete,
        reset_cache => flusher_reset_cache
    );
end architecture;
