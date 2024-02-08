library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_pipeline_idregRegister is
    port (
        clk : in std_logic;
        -- Control in
        stall : in boolean;
        nop : in boolean;
        -- Pipeline control in
        registerControlWordIn : in riscv32_RegisterControlWord_type;
        executeControlWordIn : in riscv32_ExecuteControlWord_type;
        memoryControlWordIn : in riscv32_MemoryControlWord_type;
        writeBackControlWordIn : in riscv32_WriteBackControlWord_type;
        -- Pipeline data in
        isBubbleIn : in boolean;
        programCounterIn : in riscv32_address_type;
        rs1AddressIn : in riscv32_registerFileAddress_type;
        rs2AddressIn : in riscv32_registerFileAddress_type;
        immidiateIn : in riscv32_data_type;
        uimmidiateIn : in riscv32_data_type;
        rdAddressIn : in riscv32_registerFileAddress_type;
        -- Pipeline control out
        registerControlWordOut : out riscv32_RegisterControlWord_type;
        executeControlWordOut : out riscv32_ExecuteControlWord_type;
        memoryControlWordOut : out riscv32_MemoryControlWord_type;
        writeBackControlWordOut : out riscv32_WriteBackControlWord_type;
        -- Pipeline data out
        isBubbleOut : out boolean;
        programCounterOut : out riscv32_address_type;
        rs1AddressOut : out riscv32_registerFileAddress_type;
        rs2AddressOut : out riscv32_registerFileAddress_type;
        immidiateOut : out riscv32_data_type;
        uimmidiateOut : out riscv32_data_type;
        rdAddressOut : out riscv32_registerFileAddress_type
    );
end entity;

architecture behaviourial of riscv32_pipeline_idregRegister is
begin
    process(clk)
        variable registerControlWord_var : riscv32_RegisterControlWord_type := riscv32_registerControlWordAllFalse;
        variable executeControlWord_var : riscv32_ExecuteControlWord_type := riscv32_executeControlWordAllFalse;
        variable memoryControlWord_var : riscv32_MemoryControlWord_type := riscv32_memoryControlWordAllFalse;
        variable writeBackControlWord_var : riscv32_WriteBackControlWord_type := riscv32_writeBackControlWordAllFalse;
        variable isBubbleOut_buf : boolean := true;
    begin
        if rising_edge(clk) then
            if nop then
                executeControlWord_var := riscv32_executeControlWordAllFalse;
                memoryControlWord_var := riscv32_memoryControlWordAllFalse;
                writeBackControlWord_var := riscv32_writeBackControlWordAllFalse;
                registerControlWord_var := riscv32_registerControlWordAllFalse;
                isBubbleOut_buf := true;
            elsif not stall then
                executeControlWord_var := executeControlWordIn;
                memoryControlWord_var := memoryControlWordIn;
                writeBackControlWord_var := writeBackControlWordIn;
                registerControlWord_var := registerControlWordIn;
                programCounterOut <= programCounterIn;
                rs1AddressOut <= rs1AddressIn;
                rs2AddressOut <= rs2AddressIn;
                immidiateOut <= immidiateIn;
                uimmidiateOut <= uimmidiateIn;
                rdAddressOut <= rdAddressIn;
                isBubbleOut_buf := isBubbleIn;
            end if;
        end if;
        registerControlWordOut <= registerControlWord_var;
        executeControlWordOut <= executeControlWord_var;
        memoryControlWordOut <= memoryControlWord_var;
        writeBackControlWordOut <= writeBackControlWord_var;
        isBubbleOut <= isBubbleOut_buf;
    end process;

end architecture;
