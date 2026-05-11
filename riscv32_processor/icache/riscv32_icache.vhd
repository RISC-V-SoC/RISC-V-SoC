library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.math_real.all;

library work;
use work.riscv32_pkg.all;
use work.bus_pkg.all;

entity riscv32_icache is
    generic (
        line_count_log2b : natural;
        bank_count_log2b : natural range 0 to line_count_log2b
    );
    port (
        clk : in std_logic;
        rst : in boolean;

        requestAddress : in riscv32_address_type;
        instructionOut : out riscv32_instruction_type;
        instructionIn : in riscv32_instruction_type;

        do_write : in boolean;
        miss : out boolean
    );
end entity;

architecture behaviourial of riscv32_icache is
    constant sub_word_part_lsb : natural := 0;
    constant sub_word_part_msb : natural := riscv32_address_width_log2b - riscv32_byte_width_log2b - 1;
    constant index_part_lsb : natural := riscv32_address_width_log2b - riscv32_byte_width_log2b;
    constant index_part_msb : natural := index_part_lsb + line_count_log2b - 1;
    constant tag_part_lsb : natural := index_part_msb + 1;
    constant tag_part_msb : natural := riscv32_instruction_type'high;

    constant bank_count : natural := 1;
    constant line_count : natural := 2**line_count_log2b / bank_count;

    subtype index_type is natural range 0 to line_count - 1;
    subtype tag_type is std_logic_vector(tag_part_msb - tag_part_lsb downto 0);

    type cache_line_type is record
        instruction : riscv32_address_type;
        tag : tag_type;
    end record;

    subtype valid_line_array is boolean_vector(line_count - 1 downto 0);

    type cache_line_array is array (line_count - 1 downto 0) of cache_line_type;

    signal cache : cache_line_array;
    signal valid : valid_line_array := (others => false);
    signal index : index_type;
    signal tag : tag_type;

    signal hit : boolean;
begin
    index <= to_integer(unsigned(requestAddress(index_part_msb downto index_part_lsb)));
    tag <= requestAddress(tag_part_msb downto tag_part_lsb);

    miss <= not hit;

    determine_hit: process(index, tag, cache, valid)
    begin
        if cache(index).tag = tag and valid(index) then
            hit <= true;
            instructionOut <= cache(index).instruction;
        else
            hit <= false;
            instructionOut <= (others => '-');
        end if;
    end process;

    update_data: process(clk)
    begin
        if rising_edge(clk) then
            if rst then
                valid <=(others => false);
            elsif do_write then
                valid(index) <= true;
                cache(index).tag <= tag;
                cache(index).instruction <= instructionIn;
            end if;
        end if;
    end process;

end architecture;
