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
    constant index_part_msb : natural := index_part_lsb + line_count_log2b - bank_count_log2b - 1;
    constant tag_part_lsb : natural := index_part_msb + 1;
    constant tag_part_msb : natural := riscv32_instruction_type'high;

    constant bank_count : natural := 2**bank_count_log2b;
    constant line_count : natural := 2**line_count_log2b / bank_count;

    subtype index_type is natural range 0 to line_count - 1;
    subtype tag_type is std_logic_vector(tag_part_msb - tag_part_lsb downto 0);
    type tag_type_array is array(line_count - 1 downto 0) of tag_type;
    subtype age_type is unsigned(bank_count_log2b - 1 downto 0);
    type bank_age_type_array is array(bank_count - 1 downto 0) of age_type;
    type line_age_type_array is array(line_count - 1 downto 0) of age_type;
    constant max_age : age_type := (others => '1');
    constant min_age : age_type := (others => '0');

    subtype valid_line_array is boolean_vector(line_count - 1 downto 0);

    signal hits_from_bank : boolean_vector(bank_count - 1 downto 0);
    signal instructions_from_bank : riscv32_instruction_array(bank_count - 1 downto 0);
    signal ages_from_bank : bank_age_type_array;

    signal reset_age_to_bank : boolean_vector(bank_count - 1 downto 0) := (others => false);
    signal increment_age_to_bank : boolean_vector(bank_count - 1 downto 0) := (others => false);
    signal allow_write_to_bank : boolean_vector(bank_count - 1 downto 0) := (others => false);
begin
    banks: for bank_index in 0 to bank_count - 1 generate
        bank_handling : process(all)
            variable instructions : riscv32_instruction_array(line_count - 1 downto 0);
            variable tags : tag_type_array;
            variable ages : line_age_type_array;
            variable valid : valid_line_array := (others => false);
            variable index : index_type;
            variable tag : tag_type;
        begin
            index := to_integer(unsigned(requestAddress(index_part_msb downto index_part_lsb)));
            tag := requestAddress(tag_part_msb downto tag_part_lsb);
            if rising_edge(clk) then
                if rst then
                    valid := (others => false);
                elsif do_write and allow_write_to_bank(bank_index) then
                    valid(index) := true;
                    tags(index) := tag;
                    instructions(index) := instructionIn;
                    ages(index) := min_age;
                elsif (do_write and not allow_write_to_bank(bank_index)) or (increment_age_to_bank(bank_index)) then
                    if ages(index) < max_age then
                        ages(index) := ages(index) + 1;
                    end if;
                elsif reset_age_to_bank(bank_index) then
                    ages(index) := min_age;
                end if;
            end if;

            if tags(index) = tag and valid(index) then
                hits_from_bank(bank_index) <= true;
                instructions_from_bank(bank_index) <= instructions(index);
            else
                hits_from_bank(bank_index) <= false;
                instructions_from_bank(bank_index) <= (others => '-');
            end if;

            if valid(index) then
                ages_from_bank(bank_index) <= ages(index);
            else
                ages_from_bank(bank_index) <= max_age;
            end if;
        end process;
    end generate;

    management : process(hits_from_bank, instructions_from_bank, ages_from_bank)
        variable has_hit : boolean;
        variable bank_hit_index : natural range 0 to bank_count - 1 := 0;
        variable bank_hit_age : age_type;
    begin
        has_hit := false;
        bank_hit_index := 0;
        bank_hit_age := min_age;
        for i in 0 to bank_count - 1 loop
            if hits_from_bank(i) then
                has_hit := true;
                bank_hit_index := i;
                bank_hit_age := ages_from_bank(i);
                exit;
            end if;
        end loop;

        if has_hit then
            miss <= false;
            instructionOut <= instructions_from_bank(bank_hit_index);
        else
            miss <= true;
            instructionOut <= (others => '-');
        end if;

        allow_write_to_bank <= (others => false);
        for i in 0 to bank_count - 1 loop
            if ages_from_bank(i) = max_age or bank_count_log2b = 0 then
                allow_write_to_bank(i) <= true;
                exit;
            end if;
        end loop;

        reset_age_to_bank <= (others => false);
        increment_age_to_bank <= (others => false);
        if has_hit then
            for i in 0 to bank_count - 1 loop
                if i = bank_hit_index then
                    reset_age_to_bank(i) <= true;
                elsif ages_from_bank(i) < bank_hit_age then
                    increment_age_to_bank(i) <= true;
                end if;
            end loop;
        end if;

    end process;

end architecture;
