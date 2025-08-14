library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_pipeline_stageRegister is
    port (
        clk : in std_logic;
        -- Control in
        stall : in boolean;
        rst : in boolean;
        -- Control out
        requires_service : out boolean;
        -- Exception data in
        exception_data_in : in riscv32_exception_data_type;
        exception_from_stage : in riscv32_pipeline_exception_type := exception_none;
        exception_from_stage_code : in riscv32_exception_code_type := 0;
        force_service_request : in boolean := false;
        -- Pipeline control in
        registerControlWordIn : in riscv32_RegisterControlWord_type := riscv32_registerControlWordAllFalse;
        executeControlWordIn : in riscv32_ExecuteControlWord_type := riscv32_executeControlWordAllFalse;
        memoryControlWordIn : in riscv32_MemoryControlWord_type := riscv32_memoryControlWordAllFalse;
        writeBackControlWordIn : in riscv32_WriteBackControlWord_type;
        -- Pipeline data in
        isBubbleIn : in boolean;
        programCounterIn : in riscv32_address_type := (others => '0');
        rs1AddressIn : in riscv32_registerFileAddress_type := 0;
        rs2AddressIn : in riscv32_registerFileAddress_type := 0;
        execResultIn : in riscv32_data_type := (others => '0');
        rs1DataIn : in riscv32_data_type := (others => '0');
        rs2DataIn : in riscv32_data_type := (others => '0');
        immidiateIn : in riscv32_data_type := (others => '0');
        uimmidiateIn : in riscv32_data_type := (others => '0');
        memDataReadIn : in riscv32_data_type := (others => '0');
        rdAddressIn : in riscv32_registerFileAddress_type;
        -- Exception data out
        exception_data_out : out riscv32_exception_data_type;
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
        execResultOut : out riscv32_data_type;
        rs1DataOut : out riscv32_data_type;
        rs2DataOut : out riscv32_data_type;
        immidiateOut : out riscv32_data_type;
        uimmidiateOut : out riscv32_data_type;
        memDataReadOut : out riscv32_data_type;
        rdAddressOut : out riscv32_registerFileAddress_type
    );
end entity;

architecture behaviourial of riscv32_pipeline_stageRegister is
begin
    process(clk)
        variable registerControlWord_var : riscv32_RegisterControlWord_type := riscv32_registerControlWordAllFalse;
        variable executeControlWord_var : riscv32_ExecuteControlWord_type := riscv32_executeControlWordAllFalse;
        variable memoryControlWord_var : riscv32_MemoryControlWord_type := riscv32_memoryControlWordAllFalse;
        variable writeBackControlWord_var : riscv32_WriteBackControlWord_type := riscv32_writeBackControlWordAllFalse;
        variable isBubbleOut_buf : boolean := true;
        variable is_in_exception : boolean := false;
        variable push_nop : boolean := true;
        variable exception_data_buf : riscv32_exception_data_type := riscv32_exception_data_idle;
    begin
        if rising_edge(clk) then

            if exception_from_stage /= exception_none and not isBubbleIn then
                exception_data_buf.exception_type := exception_from_stage;
                exception_data_buf.exception_code := exception_from_stage_code;
                exception_data_buf.interrupted_pc := exception_data_in.interrupted_pc;
            else
                exception_data_buf := exception_data_in;
            end if;

            if rst then
                is_in_exception := false;
                exception_data_out <= riscv32_exception_data_idle;
                push_nop := true;
            elsif stall then
                -- pass
            elsif not is_in_exception then
                exception_data_out <= exception_data_buf;
                is_in_exception := exception_data_buf.exception_type /= exception_none or force_service_request;
                push_nop := is_in_exception;
            else
                exception_data_out <= riscv32_exception_data_idle;
                push_nop := true;
            end if;

            if push_nop then
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
                execResultOut <= execResultIn;
                rs1DataOut <= rs1DataIn;
                rs2DataOut <= rs2DataIn;
                immidiateOut <= immidiateIn;
                uimmidiateOut <= uimmidiateIn;
                memDataReadOut <= memDataReadIn;
                rdAddressOut <= rdAddressIn;
                isBubbleOut_buf := isBubbleIn;
            end if;
        end if;
        registerControlWordOut <= registerControlWord_var;
        executeControlWordOut <= executeControlWord_var;
        memoryControlWordOut <= memoryControlWord_var;
        writeBackControlWordOut <= writeBackControlWord_var;
        isBubbleOut <= isBubbleOut_buf;
        requires_service <= is_in_exception;
    end process;

end architecture;
