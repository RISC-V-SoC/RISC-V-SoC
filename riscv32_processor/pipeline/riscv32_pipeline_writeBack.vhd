library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_pipeline_writeBack is
    port (
        -- From mem stage: control signals
        writeBackControlWord : in riscv32_WriteBackControlWord_type;

        -- From mem stage: data
        execResult : in riscv32_data_type;
        memDataRead : in riscv32_data_type;
        rdAddress : in riscv32_registerFileAddress_type;

        -- To instruction decode: regWrite
        regWrite : out boolean;
        regWriteAddress : out riscv32_registerFileAddress_type;
        regWriteData : out riscv32_data_type
    );
end entity;

architecture behaviourial of riscv32_pipeline_writeBack is
begin
    process(writeBackControlWord, execResult, rdAddress, memDataRead)
    begin
        regWrite <= writeBackControlWord.regWrite;
        regWriteAddress <= rdAddress;
        if writeBackControlWord.MemtoReg then
            regWriteData <= memDataRead;
        else
            regWriteData <= execResult;
        end if;
    end process;

end architecture;
