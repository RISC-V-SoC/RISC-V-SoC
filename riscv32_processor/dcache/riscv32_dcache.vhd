library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.math_real.all;

library work;
use work.riscv32_pkg.all;
use work.bus_pkg.all;

entity riscv32_dcache is
    generic (
        word_count_log2b : natural;
        tag_size : natural
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        addressIn : in riscv32_address_type;
        dataIn : in riscv32_data_type;
        dataOut : out riscv32_instruction_type;
        byteMask : in riscv32_byte_mask_type;

        doWrite : in boolean;
        miss : out boolean
    );
end entity;

architecture behaviourial of riscv32_dcache is
    -- Tag size is what is left after subtracting the fact that we store word based and the address bits that are covered by the
    -- actual cache address.
    constant address_part_lsb : natural := riscv32_address_width_log2b - riscv32_byte_width_log2b;
    constant address_part_msb : natural := address_part_lsb + word_count_log2b - 1;
    constant tag_part_lsb : natural := address_part_msb + 1;
    constant tag_part_msb : natural := tag_part_lsb + tag_size - 1;

    signal tagIn : std_logic_vector(tag_size - 1 downto 0);
    signal requestAddress : std_logic_vector(word_count_log2b - 1 downto 0);
    signal hit : boolean;
begin

    tagIn <= addressIn(tag_part_msb downto tag_part_lsb);
    requestAddress <= addressIn(address_part_msb downto address_part_lsb);

    miss <= not hit;

    dcache_bank : entity work.riscv32_dcache_bank
    generic map (
        word_count_log2b => word_count_log2b,
        tag_size => tag_size
    ) port map (
        clk => clk,
        rst => rst,
        requestAddress => requestAddress,
        dataOut => dataOut,
        dataIn => dataIn,
        tagIn => tagIn,
        byteMask => byteMask,
        hit => hit,
        doWrite => doWrite
    );
end architecture;
