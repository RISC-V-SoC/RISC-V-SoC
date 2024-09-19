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
        tagIn : in std_logic_vector(tag_size - 1 downto 0);

        dataIn_forced : in riscv32_data_type;
        doWrite_forced : in boolean;
        byteMask_forced : in riscv32_byte_mask_type;

        dataIn_onHit : in riscv32_data_type;
        doWrite_onHit : in boolean;
        byteMask_onHit : in riscv32_byte_mask_type;

        dataOut : out riscv32_data_type;
        hit : out boolean
    );
end entity;

architecture behaviourial of riscv32_dcache_bank is
    type tag_array is array (natural range <>) of std_logic_vector(tag_size - 1 downto 0);
    type valid_array is array (natural range <>) of boolean;

    constant word_count : natural := 2**word_count_log2b;
begin
    process(clk, requestAddress)
        variable dataBank : riscv32_data_array(0 to word_count - 1);
        variable tagBank : tag_array(0 to word_count - 1);
        variable validBank : valid_array(0 to word_count - 1);
        variable actualAddress : natural range 0 to word_count - 1;
        variable hit_buf : boolean;
    begin
        actualAddress := to_integer(unsigned(requestAddress));
        if rising_edge(clk) then
            if rst = '1' then
                validBank := (others => false);
            elsif doWrite_forced then
                validBank(actualAddress) := true;
                tagBank(actualAddress) := tagIn;
                for i in 0 to byteMask_forced'high loop
                    if byteMask_forced(i) = '1' then
                        dataBank(actualAddress)(((i+1)*riscv32_byte_width) - 1 downto i*riscv32_byte_width) :=
                                dataIn_forced(((i+1)*riscv32_byte_width) - 1 downto i*riscv32_byte_width);
                    end if;
                end loop;
            elsif doWrite_onHit and tagBank(actualAddress) = tagIn and validBank(actualAddress) then
                for i in 0 to byteMask_onHit'high loop
                    if byteMask_onHit(i) = '1' then
                        dataBank(actualAddress)(((i+1)*riscv32_byte_width) - 1 downto i*riscv32_byte_width) :=
                                dataIn_onHit(((i+1)*riscv32_byte_width) - 1 downto i*riscv32_byte_width);
                    end if;
                end loop;
            end if;
        end if;
        dataOut <= dataBank(actualAddress);
        hit <= tagBank(actualAddress) = tagIn and validBank(actualAddress);
    end process;

end architecture;
