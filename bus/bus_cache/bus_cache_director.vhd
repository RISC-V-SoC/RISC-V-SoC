library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;

entity bus_cache_director is
    generic (
        words_per_line_log2b : natural range 0 to natural'high;
        total_line_count_log2b : natural range 1 to natural'high;
        bank_count_log2b : natural range 1 to natural'high
    );
    port (
        clk : in std_logic;
        rst : in boolean;

        address : in bus_aligned_address_type;
        line_index : in natural range 0 to 2**total_line_count_log2b - 1;
        index_mode : in boolean;

        word_index_from_frontend : in natural range 0 to 2**words_per_line_log2b - 1;
        data_from_frontend : in bus_data_type;
        bytemask_from_frontend : in bus_byte_mask_type;
        data_to_frontend : out bus_data_type;
        do_write_from_frontend : in boolean;
        do_read_from_frontend : in boolean;

        word_index_from_backend : in natural range 0 to 2**words_per_line_log2b - 1;
        data_from_backend : in bus_data_type;
        data_to_backend : out bus_data_type;
        do_write_from_backend : in boolean;
        mark_line_clean : in boolean;

        reconstructed_address : out bus_aligned_address_type;

        hit : out boolean;
        dirty : out boolean
    );
end entity;

architecture behaviourial of bus_cache_director is
    constant words_per_line : natural := 2**words_per_line_log2b;
    constant total_line_count : natural := 2**total_line_count_log2b;
    constant bank_count : natural := 2**bank_count_log2b;

    constant line_count_log2b : natural := total_line_count_log2b - bank_count_log2b;
    constant max_age : natural := 2**bank_count_log2b - 1;

    type age_array_type is array(0 to bank_count - 1) of natural range 0 to max_age;

    signal bank_line_index : natural range 0 to 2**line_count_log2b - 1;
    signal bank_index : natural range 0 to bank_count - 1;

    signal data_to_frontend_array : bus_data_array(0 to bank_count - 1);
    signal do_write_from_frontend_array : boolean_vector(0 to bank_count - 1);
    signal data_to_backend_array : bus_data_array(0 to bank_count - 1);
    signal do_write_from_backend_array : boolean_vector(0 to bank_count - 1);
    signal mark_line_clean_array : boolean_vector(0 to bank_count - 1);
    signal reset_age_array : boolean_vector(0 to bank_count - 1);
    signal increment_age_array : boolean_vector(0 to bank_count - 1);
    signal miss_array : boolean_vector(0 to bank_count - 1);
    signal dirty_array : boolean_vector(0 to bank_count - 1);
    signal age_array : age_array_type;
    signal reconstructed_address_array : bus_aligned_address_array(0 to bank_count - 1);

    signal hit_index : natural range 0 to bank_count - 1;
    signal evict_index : natural range 0 to bank_count - 1;

    signal hit_age : natural range 0 to max_age;

    signal hit_index_buf : natural range 0 to bank_count - 1;
    signal evict_index_buf : natural range 0 to bank_count - 1;
    signal hit_age_buf : natural range 0 to max_age;
    signal age_array_buf : age_array_type;
begin
    assert(total_line_count_log2b > bank_count_log2b);

    bank_line_index <= line_index rem 2**line_count_log2b;
    bank_index <= line_index / 2**line_count_log2b;

    hit <= not miss_array(hit_index);
    data_to_frontend <= data_to_frontend_array(hit_index);
    hit_age <= age_array(hit_index);

    index_handling : process(index_mode, evict_index, bank_index, data_to_backend_array, reconstructed_address_array, dirty_array)
    begin
        if index_mode then
            data_to_backend <= data_to_backend_array(bank_index);
            reconstructed_address <= reconstructed_address_array(bank_index);
            dirty <= dirty_array(bank_index);
        else
            data_to_backend <= data_to_backend_array(evict_index);
            reconstructed_address <= reconstructed_address_array(evict_index);
            dirty <= dirty_array(evict_index);
        end if;
    end process;

    hit_handling : process(miss_array)
    begin
        hit_index <= 0;
        for i in 0 to bank_count - 1 loop
            if not miss_array(i) then
                hit_index <= i;
            end if;
        end loop;
    end process;

    evict_handling : process(age_array)
    begin
        evict_index <= 0;
        for i in bank_count - 1 downto 0 loop
            if age_array(i) = max_age then
                evict_index <= i;
            end if;
        end loop;
    end process;

    feedback_break : process(clk)
    begin
        if rising_edge(clk) then
            hit_index_buf <= hit_index;
            evict_index_buf <= evict_index;
            hit_age_buf <= hit_age;
            age_array_buf <= age_array;
        end if;
    end process;

    write_command_handling : process(hit_index_buf, evict_index_buf, do_write_from_frontend, do_write_from_backend, mark_line_clean)
    begin
        for i in 0 to bank_count - 1 loop
            do_write_from_frontend_array(i) <= do_write_from_frontend and i = hit_index_buf;
            do_write_from_backend_array(i) <= do_write_from_backend and i = evict_index_buf;
            mark_line_clean_array(i) <= mark_line_clean and i = evict_index_buf;
        end loop;
    end process;

    age_handling : process(clk, do_read_from_frontend, do_write_from_frontend, hit_index_buf, hit_age_buf, age_array_buf)
        variable bank_operation : boolean;
    begin
        bank_operation := do_read_from_frontend or do_write_from_frontend;
        for i in 0 to bank_count - 1 loop
            reset_age_array(i) <= bank_operation and i = hit_index_buf;
            increment_age_array(i) <= bank_operation and i /= hit_index_buf and age_array_buf(i) <= hit_age_buf;
        end loop;
    end process;


    banks : for index in 0 to bank_count - 1 generate
        bank : entity work.bus_cache_bank
        generic map (
            words_per_line_log2b => words_per_line_log2b,
            line_count_log2b => line_count_log2b,
            max_age => max_age
        ) port map (
            clk => clk,
            rst => rst,

            address => address,
            line_index => bank_line_index,
            index_mode => index_mode,

            word_index_from_frontend => word_index_from_frontend,
            data_from_frontend => data_from_frontend,
            bytemask_from_frontend => bytemask_from_frontend,
            data_to_frontend => data_to_frontend_array(index),
            do_write_from_frontend => do_write_from_frontend_array(index),

            word_index_from_backend => word_index_from_backend,
            data_from_backend => data_from_backend,
            data_to_backend => data_to_backend_array(index),
            do_write_from_backend => do_write_from_backend_array(index),
            mark_line_clean => mark_line_clean_array(index),

            reset_age => reset_age_array(index),
            increase_age => increment_age_array(index),

            miss => miss_array(index),
            dirty => dirty_array(index),
            age => age_array(index),
            reconstructed_address => reconstructed_address_array(index)
        );
    end generate;
end architecture;
