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

    signal address_buf : bus_aligned_address_type;
    signal index_mode_buf : boolean;
    signal word_index_from_frontend_buf : natural range 0 to 2**words_per_line_log2b - 1;
    signal data_from_frontend_buf : bus_data_type;
    signal bytemask_from_frontend_buf : bus_byte_mask_type;
    signal word_index_from_backend_buf : natural range 0 to 2**words_per_line_log2b - 1;
    signal data_from_backend_buf : bus_data_type;
begin
    assert(total_line_count_log2b > bank_count_log2b);

    input_buffer : process(clk)
    begin
        if rising_edge(clk) then
            address_buf <= address;
            bank_line_index <= line_index rem 2**line_count_log2b;
            bank_index <= line_index / 2**line_count_log2b;
            index_mode_buf <= index_mode;
            word_index_from_frontend_buf <= word_index_from_frontend;
            data_from_frontend_buf <= data_from_frontend;
            bytemask_from_frontend_buf <= bytemask_from_frontend;
            word_index_from_backend_buf <= word_index_from_backend;
            data_from_backend_buf <= data_from_backend;
        end if;
    end process;

    output_buffer : process(clk)
        variable data_to_frontend_array_reg : bus_data_array(0 to bank_count - 1);
        variable data_to_backend_array_reg : bus_data_array(0 to bank_count - 1);
        variable miss_array_reg : boolean_vector(0 to bank_count - 1);
        variable dirty_array_reg : boolean_vector(0 to bank_count - 1);
        variable reconstructed_address_array_reg : bus_aligned_address_array(0 to bank_count - 1);
        variable age_array_reg : age_array_type;

        variable hit_index : natural range 0 to bank_count - 1;
        variable evict_index : natural range 0 to bank_count - 1;
        variable hit_age : natural range 0 to max_age;
        variable bank_operation : boolean;
    begin
        if rising_edge(clk) then
            data_to_frontend_array_reg := data_to_frontend_array;
            data_to_backend_array_reg := data_to_backend_array;
            reconstructed_address_array_reg := reconstructed_address_array;
            miss_array_reg := miss_array;
            age_array_reg := age_array;
            dirty_array_reg := dirty_array;

            hit_index := 0;
            for i in 0 to bank_count - 1 loop
                if not miss_array_reg(i) then
                    hit_index := i;
                end if;
            end loop;

            evict_index := 0;
            for i in bank_count - 1 downto 0 loop
                if age_array(i) = max_age then
                    evict_index := i;
                end if;
            end loop;

            hit <= not miss_array_reg(hit_index);
            data_to_frontend <= data_to_frontend_array_reg(hit_index);
            if index_mode then
                data_to_backend <= data_to_backend_array_reg(bank_index);
                reconstructed_address <= reconstructed_address_array_reg(bank_index);
                dirty <= dirty_array_reg(bank_index);
            else
                data_to_backend <= data_to_backend_array_reg(evict_index);
                reconstructed_address <= reconstructed_address_array_reg(evict_index);
                dirty <= dirty_array_reg(evict_index);
            end if;

            hit_age := age_array_reg(hit_index);

            for i in 0 to bank_count - 1 loop
                do_write_from_frontend_array(i) <= do_write_from_frontend and i = hit_index;
                do_write_from_backend_array(i) <= do_write_from_backend and i = evict_index;
                mark_line_clean_array(i) <= mark_line_clean and i = evict_index;
            end loop;

            bank_operation := do_read_from_frontend or do_write_from_frontend;
            for i in 0 to bank_count - 1 loop
                reset_age_array(i) <= bank_operation and i = hit_index;
                increment_age_array(i) <= bank_operation and i /= hit_index and age_array_reg(i) <= hit_age;
            end loop;
        end if;
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

            address => address_buf,
            line_index => bank_line_index,
            index_mode => index_mode_buf,

            word_index_from_frontend => word_index_from_frontend_buf,
            data_from_frontend => data_from_frontend_buf,
            bytemask_from_frontend => bytemask_from_frontend_buf,
            data_to_frontend => data_to_frontend_array(index),
            do_write_from_frontend => do_write_from_frontend_array(index),

            word_index_from_backend => word_index_from_backend_buf,
            data_from_backend => data_from_backend_buf,
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
