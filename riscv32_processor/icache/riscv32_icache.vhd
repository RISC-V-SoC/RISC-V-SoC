library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.math_real.all;

library work;
use work.riscv32_pkg.all;
use work.bus_pkg.all;

entity riscv32_icache is
    generic (
        word_count_log2b : natural;
        tag_size : natural
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        requestAddress : in riscv32_address_type;
        instructionOut : out riscv32_instruction_type;
        instructionIn : in riscv32_instruction_type;

        doWrite : in boolean;
        miss : out boolean
    );
end entity;

architecture behaviourial of riscv32_icache is

    constant sub_word_part_lsb : natural := 0;
    constant sub_word_part_msb : natural := riscv32_address_width_log2b - riscv32_byte_width_log2b - 1;
    constant address_part_lsb : natural := riscv32_address_width_log2b - riscv32_byte_width_log2b;
    constant address_part_msb : natural := address_part_lsb + word_count_log2b - 1;
    constant tag_part_lsb : natural := address_part_msb + 1;
    constant tag_part_msb : natural := tag_part_lsb + tag_size - 1;

    signal tagToBank : std_logic_vector(tag_size - 1 downto 0);
    signal hit : boolean;
begin
    tagToBank <= requestAddress(tag_part_msb downto tag_part_lsb);
    miss <= not hit;

    icache_bank : entity work.riscv32_icache_bank
    generic map (
        word_count_log2b => word_count_log2b,
        tag_size => tag_size
    ) port map (
        clk => clk,
        rst => rst,
        requestAddress => requestAddress(address_part_msb downto address_part_lsb),
        instructionOut => instructionOut,
        instructionIn => instructionIn,
        tagIn => tagToBank,
        hit => hit,
        doWrite => doWrite
    );
end architecture;
