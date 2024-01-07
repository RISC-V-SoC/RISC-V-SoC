library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_pipeline_exmemRegister is
    port (
        clk : in std_logic;
        -- Control in
        stall : in boolean;
        nop : in boolean;
        -- Pipeline control in
        memoryControlWordIn : in riscv32_MemoryControlWord_type;
        writeBackControlWordIn : in riscv32_WriteBackControlWord_type;
        -- Pipeline data in
        execResultIn : in riscv32_data_type;
        rs1DataIn : in riscv32_data_type;
        rs2DataIn : in riscv32_data_type;
        rdAddressIn : in riscv32_registerFileAddress_type;
        uimmidiateIn : in riscv32_data_type;
        -- Pipeline control out
        memoryControlWordOut : out riscv32_MemoryControlWord_type;
        writeBackControlWordOut : out riscv32_WriteBackControlWord_type;
        -- Pipeline data out
        execResultOut : out riscv32_data_type;
        rs1DataOut : out riscv32_data_type;
        rs2DataOut : out riscv32_data_type;
        rdAddressOut : out riscv32_registerFileAddress_type;
        uimmididateOut : out riscv32_data_type
    );
end entity;

architecture behaviourial of riscv32_pipeline_exmemRegister is
begin
    process(clk)
        variable memoryControlWordOut_buf : riscv32_MemoryControlWord_type := riscv32_memoryControlWordAllFalse;
        variable writeBackControlWordOut_buf : riscv32_WriteBackControlWord_type := riscv32_writeBackControlWordAllFalse;
    begin
        if rising_edge(clk) then
            if nop and not stall then
                memoryControlWordOut_buf := riscv32_memoryControlWordAllFalse;
                writeBackControlWordOut_buf := riscv32_writeBackControlWordAllFalse;
            elsif not stall then
                memoryControlWordOut_buf := memoryControlWordIn;
                writeBackControlWordOut_buf := writeBackControlWordIn;
                execResultOut <= execResultIn;
                rs1DataOut <= rs1DataIn;
                rs2DataOut <= rs2DataIn;
                rdAddressOut <= rdAddressIn;
                uimmididateOut <= uimmidiateIn;
            end if;
        end if;
        memoryControlWordOut <= memoryControlWordOut_buf;
        writeBackControlWordOut <= writeBackControlWordOut_buf;
    end process;
end architecture;
