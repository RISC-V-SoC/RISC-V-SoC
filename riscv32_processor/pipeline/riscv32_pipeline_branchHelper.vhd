library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_pipeline_branchHelper is
    generic (
        array_size : natural
    );
    port (
        executeControlWords : in riscv32_ExecuteControlWord_array(array_size - 1 downto 0);

        injectBubble : out boolean
    );
end entity;

architecture behaviourial of riscv32_pipeline_branchHelper is
begin
    process(executeControlWords)
    begin
        injectBubble <= false;
        for i in 0 to array_size - 1 loop
            if executeControlWords(i).is_branch_op then
                injectBubble <= true;
            end if;
        end loop;
    end process;
end architecture;
