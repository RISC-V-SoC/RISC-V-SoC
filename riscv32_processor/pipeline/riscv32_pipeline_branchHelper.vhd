library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_pipeline_branchHelper is
    port (
        executeControlWord : in riscv32_ExecuteControlWord_type;

        injectBubble : out boolean
    );
end entity;

architecture behaviourial of riscv32_pipeline_branchHelper is
begin
    injectBubble <= executeControlWord.is_branch_op;
end architecture;
