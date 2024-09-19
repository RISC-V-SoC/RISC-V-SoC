library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_dcache_bank is
    generic (
        word_count_log2b : natural;
        tag_size : natural
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        requestAddress : in std_logic_vector(word_count_log2b - 1 downto 0);
        dataOut : out riscv32_data_type;
        dataIn : in riscv32_data_type;
        tagOut : out std_logic_vector(tag_size - 1 downto 0);
        tagIn : in std_logic_vector(tag_size - 1 downto 0);
        byteMask : in riscv32_byte_mask_type;

        valid : out boolean;
        doWrite : in boolean
    );
end entity;

architecture behaviourial of riscv32_dcache_bank is
    type tag_array is array (natural range <>) of std_logic_vector(tag_size - 1 downto 0);
    type valid_array is array (natural range <>) of boolean;
    type dirty_array is array (natural range <>) of boolean;

    constant word_count : natural := 2**word_count_log2b;
begin
    process(clk, requestAddress)
        variable dataBank : riscv32_data_array(0 to word_count - 1);
        variable tagBank : tag_array(0 to word_count - 1);
        variable validBank : valid_array(0 to word_count - 1);
        variable actualAddress : natural range 0 to word_count - 1;
    begin
        actualAddress := to_integer(unsigned(requestAddress));
        if rising_edge(clk) then
            if rst = '1' then
                validBank := (others => false);
            elsif doWrite then
                validBank(actualAddress) := true;
                tagBank(actualAddress) := tagIn;
                for i in 0 to byteMask'high loop
                    if byteMask(i) = '1' then
                        dataBank(actualAddress)(((i+1)*riscv32_byte_width) - 1 downto i*riscv32_byte_width) :=
                                dataIn(((i+1)*riscv32_byte_width) - 1 downto i*riscv32_byte_width);
                    end if;
                end loop;
            end if;
        end if;
        valid <= validBank(actualAddress);
        tagOut <= tagBank(actualAddress);
        dataOut <= dataBank(actualAddress);
    end process;

end architecture;
