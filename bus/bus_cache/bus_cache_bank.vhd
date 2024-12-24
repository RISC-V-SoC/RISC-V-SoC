library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;

entity bus_cache_bank is
    generic (
        words_per_line_log2b : natural range 0 to natural'high;
        line_count_log2b : natural range 1 to natural'high;
        max_age : natural range 1 to natural'high
    );
    port (
        clk : in std_logic;
        rst : in boolean;

        address : in bus_aligned_address_type;
        line_index : in natural range 0 to 2**line_count_log2b - 1;
        index_mode : in boolean;

        word_index_from_frontend : in natural range 0 to 2**words_per_line_log2b - 1;
        data_from_frontend : in bus_data_type;
        bytemask_from_frontend : in bus_byte_mask_type;
        data_to_frontend : out bus_data_type;
        do_write_from_frontend : in boolean;

        word_index_from_backend : in natural range 0 to 2**words_per_line_log2b - 1;
        data_from_backend : in bus_data_type;
        data_to_backend : out bus_data_type;
        do_write_from_backend : in boolean;

        mark_line_clean : in boolean;

        reset_age : in boolean;
        increase_age : in boolean;

        miss : out boolean;
        dirty : out boolean;
        age : out natural range 0 to max_age;
        reconstructed_address : out bus_aligned_address_type
    );
end entity;

architecture behaviourial of bus_cache_bank is
    constant words_per_line : natural := 2**words_per_line_log2b;
    constant line_count : natural := 2**line_count_log2b;

    constant ignored_address_part_msb : natural := words_per_line_log2b + bus_bytes_per_word_log2b - 1;
    constant address_line_index_lsb : natural := ignored_address_part_msb + 1;
    constant address_line_index_msb : natural := address_line_index_lsb + line_count_log2b - 1;
    constant address_tag_lsb : natural := address_line_index_msb + 1;
    constant address_tag_msb : natural := address'high;

    subtype tag_type is std_logic_vector(address_tag_msb - address_tag_lsb downto 0);
    type tag_array_type is array(line_count-1 downto 0) of tag_type;

    signal address_line_index : natural range 0 to line_count-1;

    signal actual_line_index : natural range 0 to line_count - 1;
    signal valid : boolean;
    signal dirty_buf : boolean;
    signal tag : tag_type;
    signal address_tag : tag_type;
    signal age_buf : natural range 0 to max_age;

    signal data_bank : bus_data_array(0 to line_count * words_per_line - 1);
begin
    address_line_index <= to_integer(unsigned(address(address_line_index_msb downto address_line_index_lsb)));
    address_tag <= address(address_tag_msb downto address_tag_lsb);
    miss <= not valid or address_tag /= tag;
    dirty <= false when not valid else dirty_buf;
    age <= max_age when not valid else age_buf;

    actual_line_index_handling : process(address_line_index, line_index, index_mode)
    begin
        if index_mode then
            actual_line_index <= line_index;
        else
            actual_line_index <= address_line_index;
        end if;
    end process;

    reconstruct_address : process(tag, actual_line_index)
    begin
        reconstructed_address(address_tag_msb downto address_tag_lsb) <= tag;
        reconstructed_address(address_line_index_msb downto address_line_index_lsb) <= std_logic_vector(to_unsigned(actual_line_index, address_line_index_msb - address_line_index_lsb + 1));
        reconstructed_address(ignored_address_part_msb downto reconstructed_address'low) <= (others => '0');
    end process;

    valid_handling : process(clk)
        variable valid_bank : boolean_vector(line_count-1 downto 0) := (others => false);
    begin
        if rising_edge(clk) then
            valid <= valid_bank(actual_line_index);
            if rst then
                valid_bank := (others => false);
            elsif mark_line_clean then
                valid_bank(actual_line_index) := true;
            elsif do_write_from_backend then
                valid_bank(actual_line_index) := false;
            end if;
        end if;
    end process;

    data_storage : process(clk)
        variable data_bank : bus_data_array(0 to line_count * words_per_line - 1);

        variable backend_word_index : natural range 0 to data_bank'high;
        variable frontend_word_index : natural range 0 to data_bank'high;
    begin
        -- To make Vivado recognize that this is a true dual-port BRAM we need two seperate rising_edge(clk) checks
        -- Vivado recommends having two processes, but this requires a shared variable. This needs to be a protected type,
        -- which is quite hard and apparently also trips up Vivado. Alternatively, some rules can be relaxed, which is
        -- also not ideal.
        if rising_edge(clk) then
            backend_word_index := actual_line_index * words_per_line + word_index_from_backend;
            data_to_backend <= data_bank(backend_word_index);
            if do_write_from_backend then
                data_bank(backend_word_index) := data_from_backend;
            end if;
        end if;

        if rising_edge(clk) then
            frontend_word_index := actual_line_index * words_per_line + word_index_from_frontend;
            data_to_frontend <= data_bank(frontend_word_index);
            if do_write_from_frontend then
                for i in 0 to bus_bytes_per_word-1 loop
                    if bytemask_from_frontend(i) = '1' then
                        data_bank(frontend_word_index)(i*8+7 downto i*8) := data_from_frontend(i*8+7 downto i*8);
                    end if;
                end loop;
            end if;
        end if;
    end process;

    dirty_handling : process(clk)
        variable dirty_bank : boolean_vector(line_count-1 downto 0) := (others => false);
    begin
        if rising_edge(clk) then
            dirty_buf <= dirty_bank(actual_line_index);
            if mark_line_clean then
                dirty_bank(actual_line_index) := false;
            elsif do_write_from_frontend then
                dirty_bank(actual_line_index) := true;
            end if;
        end if;
    end process;

    tag_handling : process(clk)
        variable tag_bank : tag_array_type;
    begin
        if rising_edge(clk) then
            tag <= tag_bank(actual_line_index);
            if do_write_from_backend then
                tag_bank(actual_line_index) := address_tag;
            end if;
        end if;
    end process;

    age_handling : process(clk)
        type age_array_type is array(line_count-1 downto 0) of natural range 0 to max_age;
        variable age_bank : age_array_type;
    begin
        if rising_edge(clk) then
            age_buf <= age_bank(actual_line_index);

            if reset_age then
                age_bank(actual_line_index) := 0;
            elsif mark_line_clean then
                age_bank(actual_line_index) := max_age;
            elsif increase_age and age_buf < max_age then
                age_bank(actual_line_index) := age_buf + 1;
            end if;
        end if;
    end process;
end architecture;
