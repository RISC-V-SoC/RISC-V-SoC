library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity riscv32_cycleCounter is
    port (
        clk : in std_logic;
        reset : in boolean;

        value : out unsigned(63 downto 0)
    );
end entity;

architecture behaviourial of riscv32_cycleCounter is
begin
    process(clk)
        variable value_buf : unsigned(value'range) := (others => '0');
    begin
        if rising_edge(clk) then
            if reset then
                value_buf := (others => '0');
            else
                value_buf := value_buf + 1;
            end if;
        end if;
        value <= value_buf;
    end process;
end architecture;
