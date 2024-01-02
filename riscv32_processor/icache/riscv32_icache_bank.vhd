library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_icache_bank is
    generic (
        word_count_log2b : natural;
        tag_size : natural
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        requestAddress : in std_logic_vector(word_count_log2b - 1 downto 0);
        instructionOut : out riscv32_instruction_type;
        instructionIn : in riscv32_instruction_type;
        tagOut : out std_logic_vector(tag_size - 1 downto 0);
        tagIn : in std_logic_vector(tag_size - 1 downto 0);

        valid : out boolean;
        doWrite : in boolean
    );
end entity;

architecture behaviourial of riscv32_icache_bank is
    type tag_array is array (natural range <>) of std_logic_vector(tag_size - 1 downto 0);
    type valid_array is array (natural range <>) of boolean;

    constant word_count : natural := 2**word_count_log2b;
begin
    process(clk, requestAddress)
        variable instructionBank : riscv32_instruction_array(0 to word_count - 1);
        variable tagBank : tag_array(0 to word_count - 1);
        variable validBank : valid_array(0 to word_count - 1);
        variable actualAddress : natural range 0 to word_count - 1;
    begin
        actualAddress := to_integer(unsigned(requestAddress));
        if rising_edge(clk) then
            if rst = '1' then
                validBank := (others => false);
            elsif doWrite then
                instructionBank(actualAddress) := instructionIn;
                tagBank(actualAddress) := tagIn;
                validBank(actualAddress) := true;
            end if;
        end if;

        instructionOut <= instructionBank(actualAddress);
        tagOut <= tagBank(actualAddress);
        valid <= validBank(actualAddress);
    end process;
end architecture;
