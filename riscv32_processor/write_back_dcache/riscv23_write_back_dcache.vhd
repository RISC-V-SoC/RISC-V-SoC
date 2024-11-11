library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.math_real.all;

library work;
use work.riscv32_pkg.all;
use work.bus_pkg.all;

entity riscv32_write_back_dcache is
    generic (
        word_count_log2b : natural;
        cache_range_size : natural;
        cached_base_address : bus_aligned_address_type
    );
    port (
        clk : in std_logic;
        rst : in boolean;

        addressIn : in bus_aligned_address_type;

        proc_dataIn : in riscv32_data_type;
        proc_byteMask : in riscv32_byte_mask_type;
        proc_doWrite : in boolean;

        bus_dataIn : in riscv32_data_type;
        bus_doWrite : in boolean;

        dataOut : out riscv32_instruction_type;
        reconstructedAddr : out bus_aligned_address_type;
        dirty : out boolean;
        miss : out boolean
    );
end entity;

architecture behaviourial of riscv32_write_back_dcache is
    constant cache_range_size_log2 : natural := integer(ceil(log2(real(cache_range_size))));
    constant tag_size : natural := cache_range_size_log2 - word_count_log2b + bus_byte_size_log2b - bus_address_width_log2b;
    constant line_address_part_lsb : natural := bus_bytes_per_word_log2b;
    constant line_address_part_msb : natural := line_address_part_lsb + word_count_log2b - 1;
    constant tag_part_lsb : natural := line_address_part_msb + 1;
    constant tag_part_msb : natural := tag_part_lsb + tag_size - 1;

    constant word_count : natural := 2**word_count_log2b;

    type tag_array is array (natural range 0 to word_count - 1) of std_logic_vector(tag_size - 1 downto 0);
    type valid_array is array (natural range 0 to word_count - 1) of boolean;

    signal cachedTag : std_logic_vector(tag_size - 1 downto 0);
begin
    reconstruct_address : process(cachedTag, addressIn)
    begin
        reconstructedAddr <= cached_base_address;
        reconstructedAddr(line_address_part_msb downto line_address_part_lsb) <= addressIn(line_address_part_msb downto line_address_part_lsb);
        reconstructedAddr(tag_part_msb downto tag_part_lsb) <= cachedTag;
    end process;

    cache_bank : process(clk, addressIn)
        variable lineAddress : natural range 0 to word_count - 1;
        variable data_bank : riscv32_data_array(0 to word_count - 1);
        variable tag_bank : tag_array;
        variable valid_bank : boolean_vector(0 to word_count - 1) := (others => false);
        variable dirty_bank : boolean_vector(0 to word_count - 1) := (others => false);
        variable byte_lsb : natural;
        variable byte_msb : natural;
        variable tag : std_logic_vector(tag_size - 1 downto 0);
    begin
        lineAddress := to_integer(unsigned(addressIn(line_address_part_msb downto line_address_part_lsb)));
        tag := addressIn(tag_part_msb downto tag_part_lsb);
        if rising_edge(clk) then
            if rst then
                valid_bank := (others => false);
                dirty_bank := (others => false);
            elsif bus_doWrite then
                data_bank(lineAddress) := bus_dataIn;
                tag_bank(lineAddress) := tag;
                valid_bank(lineAddress) := true;
                dirty_bank(lineAddress) := false;
            elsif proc_doWrite then
                for i in 0 to bus_bytes_per_word - 1 loop
                    byte_lsb := bus_byte_size * i;
                    byte_msb := bus_byte_size * (i + 1) - 1;
                    if proc_byteMask(i) = '1' then
                        data_bank(lineAddress)(byte_msb downto byte_lsb) := proc_dataIn(byte_msb downto byte_lsb);
                    end if;
                end loop;
                tag_bank(lineAddress) := tag;
                dirty_bank(lineAddress) := true;
                valid_bank(lineAddress) := true;
            end if;
        end if;
        dataOut <= data_bank(lineAddress);
        miss <= tag_bank(lineAddress) /= tag or not valid_bank(lineAddress);
        dirty <= dirty_bank(lineAddress);
        cachedTag <= tag_bank(lineAddress);
    end process;
end architecture;
