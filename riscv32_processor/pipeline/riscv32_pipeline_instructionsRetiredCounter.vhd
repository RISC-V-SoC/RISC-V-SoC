library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_pipeline_instructionsRetiredCounter is
    port (
        clk : in std_logic;
        rst : in boolean;
        stall : in boolean;
        isBubble : in boolean;
        instructionsRetiredCount : out unsigned(63 downto 0)
    );
end entity;

architecture behaviourial of  riscv32_pipeline_instructionsRetiredCounter is
begin
    process(clk)
        variable instructionsRetiredCount_buf : unsigned(instructionsRetiredCount'range) := (others => '0');
    begin
        if rising_edge(clk) then
            if rst then
                instructionsRetiredCount_buf := (others => '0');
            elsif not isBubble and not stall then
                instructionsRetiredCount_buf := instructionsRetiredCount_buf + 1;
            end if;
        end if;

        instructionsRetiredCount <= instructionsRetiredCount_buf;
    end process;
end architecture;
