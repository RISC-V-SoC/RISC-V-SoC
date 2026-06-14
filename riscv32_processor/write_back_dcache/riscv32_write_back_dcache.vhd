library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.math_real.all;

library work;
use work.riscv32_pkg.all;
use work.bus_pkg.all;

entity riscv32_write_back_dcache is
    generic (
        line_count_log2b : natural
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

        dataOut : out bus_data_type;
        reconstructedAddr : out bus_aligned_address_type;
        dirty : out boolean;
        miss : out boolean;

        line_address : in natural range 0 to 2**line_count_log2b - 1;
        line_reconstructedAddr : out bus_aligned_address_type;
        line_dataOut : out bus_data_type;
        line_dirty : out boolean
    );
end entity;

architecture behaviourial of riscv32_write_back_dcache is
    constant sub_word_part_lsb : natural := 0;
    constant sub_word_part_msb : natural := riscv32_address_width_log2b - riscv32_byte_width_log2b - 1;
    constant index_part_lsb : natural := riscv32_address_width_log2b - riscv32_byte_width_log2b;
    constant index_part_msb : natural := index_part_lsb + line_count_log2b - 1;
    constant tag_part_lsb : natural := index_part_msb + 1;
    constant tag_part_msb : natural := riscv32_data_type'high;

    constant line_count : natural := 2**line_count_log2b;

    subtype tag_type is std_logic_vector(tag_part_msb - tag_part_lsb downto 0);
    type tag_type_array is array(line_count - 1 downto 0) of tag_type;

    signal cachedTag : tag_type;

    signal line_address_cachedTag : tag_type;
begin
    reconstruct_address : process(cachedTag, addressIn)
    begin
        reconstructedAddr(index_part_msb downto index_part_lsb) <= addressIn(index_part_msb downto index_part_lsb);
        reconstructedAddr(tag_part_msb downto tag_part_lsb) <= cachedTag;
    end process;

    reconstruct_line_address : process(line_address, line_address_cachedTag)
    begin
        line_reconstructedAddr(index_part_msb downto index_part_lsb) <= std_logic_vector(to_unsigned(line_address, index_part_msb - index_part_lsb + 1));
        line_reconstructedAddr(tag_part_msb downto tag_part_lsb) <= line_address_cachedTag;
    end process;

    cache_bank : process(clk, addressIn)
        variable lineAddress : natural range 0 to line_count - 1;
        variable data_bank : riscv32_data_array(0 to line_count - 1);
        variable tag_bank : tag_type_array;
        variable valid_bank : boolean_vector(0 to line_count - 1) := (others => false);
        variable dirty_bank : boolean_vector(0 to line_count - 1) := (others => false);
        variable byte_lsb : natural;
        variable byte_msb : natural;
        variable tag : tag_type;
    begin
        lineAddress := to_integer(unsigned(addressIn(index_part_msb downto index_part_lsb)));
        tag := addressIn(tag_part_msb downto tag_part_lsb);
        if rising_edge(clk) then
            line_address_cachedTag <= tag_bank(line_address);
            line_dataOut <= data_bank(line_address);
            line_dirty <= dirty_bank(line_address);

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
