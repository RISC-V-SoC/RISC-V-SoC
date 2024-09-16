library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_pipeline_regexRegister is
    port (
        clk : in std_logic;
        -- Control in
        stall : in boolean;
        rst : in boolean;
        nop : in boolean;
        -- Exception data in
        exception_data_in : in riscv32_exception_data_type;
        -- Pipeline control in
        executeControlWordIn : in riscv32_ExecuteControlWord_type;
        memoryControlWordIn : in riscv32_MemoryControlWord_type;
        writeBackControlWordIn : in riscv32_WriteBackControlWord_type;
        -- Pipeline data in
        isBubbleIn : in boolean;
        programCounterIn : in riscv32_address_type;
        rs1DataIn : in riscv32_data_type;
        rs2DataIn : in riscv32_data_type;
        immidiateIn : in riscv32_data_type;
        uimmidiateIn : in riscv32_data_type;
        rdAddressIn : in riscv32_registerFileAddress_type;
        -- Exception data out
        exception_data_out : out riscv32_exception_data_type;
        -- Pipeline control out
        executeControlWordOut : out riscv32_ExecuteControlWord_type;
        memoryControlWordOut : out riscv32_MemoryControlWord_type;
        writeBackControlWordOut : out riscv32_WriteBackControlWord_type;
        -- Pipeline data out
        isBubbleOut : out boolean;
        programCounterOut : out riscv32_address_type;
        rs1DataOut : out riscv32_data_type;
        rs2DataOut : out riscv32_data_type;
        immidiateOut : out riscv32_data_type;
        uimmidiateOut : out riscv32_data_type;
        rdAddressOut : out riscv32_registerFileAddress_type
    );
end entity;

architecture behaviourial of riscv32_pipeline_regexRegister is
begin
    process(clk)
        variable executeControlWord_var : riscv32_ExecuteControlWord_type := riscv32_executeControlWordAllFalse;
        variable memoryControlWord_var : riscv32_MemoryControlWord_type := riscv32_memoryControlWordAllFalse;
        variable writeBackControlWord_var : riscv32_WriteBackControlWord_type := riscv32_writeBackControlWordAllFalse;
        variable isBubbleOut_buf : boolean := true;
        variable is_in_exception : boolean := false;
        variable push_nop : boolean := true;
    begin
        if rising_edge(clk) then
            if rst then
                is_in_exception := false;
                push_nop := true;
            elsif stall then
                -- pass
            elsif not is_in_exception then
                exception_data_out <= exception_data_in;
                is_in_exception := exception_data_in.carries_exception;
                push_nop := is_in_exception;
            else
                exception_data_out <= riscv32_exception_data_idle;
                push_nop := true;
            end if;

            if nop or push_nop then
                executeControlWord_var := riscv32_executeControlWordAllFalse;
                memoryControlWord_var := riscv32_memoryControlWordAllFalse;
                writeBackControlWord_var := riscv32_writeBackControlWordAllFalse;
                isBubbleOut_buf := true;
            elsif not stall then
                executeControlWord_var := executeControlWordIn;
                memoryControlWord_var := memoryControlWordIn;
                writeBackControlWord_var := writeBackControlWordIn;
                programCounterOut <= programCounterIn;
                rs1DataOut <= rs1DataIn;
                rs2DataOut <= rs2DataIn;
                immidiateOut <= immidiateIn;
                uimmidiateOut <= uimmidiateIn;
                rdAddressOut <= rdAddressIn;
                isBubbleOut_buf := isBubbleIn;
            end if;
        end if;
        executeControlWordOut <= executeControlWord_var;
        memoryControlWordOut <= memoryControlWord_var;
        writeBackControlWordOut <= writeBackControlWord_var;
        isBubbleOut <= isBubbleOut_buf;
    end process;

end architecture;
