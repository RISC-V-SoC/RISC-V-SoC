library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;
use work.riscv32_pkg.all;

entity riscv32_pipeline_instructionFetch is
    generic (
        startAddress : riscv32_address_type
    );
    port (
        clk : in std_logic;
        rst : in boolean;

        -- To/from bus controller
        requestFromBusAddress : out riscv32_address_type;
        instructionFromBus : in riscv32_instruction_type;
        has_fault : in boolean;
        exception_code : in riscv32_exception_code_type;

        -- To instructionDecode
        isBubble : out boolean;
        instructionToInstructionDecode : out riscv32_instruction_type;
        programCounter : out riscv32_address_type;
        exception_data : out riscv32_exception_data_type;

        -- From instructionDecode (unconditional jump)
        overrideProgramCounterFromID : in boolean;
        newProgramCounterFromID : in riscv32_address_type;

        -- From execute (unconditional jump or branch)
        overrideProgramCounterFromEx : in boolean;
        newProgramCounterFromEx : in riscv32_address_type;

        -- From interrupt control
        overrideProgramCounterFromInterrupt : in boolean;
        newProgramCounterFromInterrupt : in riscv32_address_type;

        injectBubble : in boolean;
        stall : in boolean
    );
end entity;

architecture behaviourial of riscv32_pipeline_instructionFetch is
    signal programCounter_buf : riscv32_address_type := startAddress;
    signal programCounterPlusFour : riscv32_address_type;
    signal nextProgramCounter : riscv32_address_type;
    signal outputNop : boolean := false;
    signal instructionToInstructionDecode_buf : riscv32_instruction_type;
    signal currentInstructionTransfersControl : boolean := false;
    signal isBubble_buf : boolean := true;
    signal is_interrupted : boolean := false;
begin

    requestFromBusAddress <= programCounter_buf;
    programCounterPlusFour <= std_logic_vector(unsigned(programCounter_buf) + 4);

    interrupt_flipflop : process(clk)
    begin
        if rising_edge(clk) then
            if overrideProgramCounterFromInterrupt or rst then
                is_interrupted <= false;
            elsif has_fault and not stall then
                is_interrupted <= true;
            end if;
        end if;
    end process;

    determineNextProgramCounter : process(overrideProgramCounterFromID, newProgramCounterFromID,
                                          overrideProgramCounterFromEx, newProgramCounterFromEx,
                                          overrideProgramCounterFromInterrupt, newProgramCounterFromInterrupt,
                                          programCounterPlusFour)
    begin
        if overrideProgramCounterFromEx then
            nextProgramCounter <= newProgramCounterFromEx;
        elsif overrideProgramCounterFromID then
            nextProgramCounter <= newProgramCounterFromID;
        elsif overrideProgramCounterFromInterrupt then
            nextProgramCounter <= newProgramCounterFromInterrupt;
        else
            nextProgramCounter <= programCounterPlusFour;
        end if;
    end process;

    programCounterControl : process(clk)
        variable active_interrupt : boolean := false;
    begin
        if rising_edge(clk) then
            outputNop <= false;
            active_interrupt := (has_fault or is_interrupted) and not overrideProgramCounterFromInterrupt;
            if rst then
                programCounter_buf <= startAddress;
            elsif stall or active_interrupt then
                -- pass
            elsif injectBubble or currentInstructionTransfersControl then
                outputNop <= true;
            else
                programCounter_buf <= nextProgramCounter;
            end if;
        end if;
    end process;

    determineOutputInstruction : process(outputNop, instructionFromBus)
    begin
        if outputNop then
            isBubble_buf <= true;
            instructionToInstructionDecode_buf <= riscv32_instructionNop;
            currentInstructionTransfersControl <= false;
        else
            isBubble_buf <= false;
            instructionToInstructionDecode_buf <= instructionFromBus;
            currentInstructionTransfersControl <= instructionFromBus(6 downto 4) = "110";
        end if;
    end process;

    IFIDRegs : process(clk)
        variable instructionBuf : riscv32_instruction_type := riscv32_instructionNop;
        variable isBubble_out : boolean := true;
        variable exception_data_clocked_out : boolean := false;
        variable exception_data_set : boolean := false;
    begin
        if rising_edge(clk) then

            if not is_interrupted then
                exception_data_clocked_out := false;
                exception_data_set := false;
            elsif exception_data_set and not stall then
                exception_data_clocked_out := true;
            end if;

            if rst then
                exception_data <= riscv32_exception_data_idle;
                exception_data_clocked_out := false;
                exception_data_set := false;
            end if;

            if rst or exception_data_clocked_out then
                instructionBuf := riscv32_instructionNop;
                isBubble_out := true;
                exception_data <= riscv32_exception_data_idle;
            elsif not stall then
                instructionBuf := instructionToInstructionDecode_buf;
                programCounter <= programCounter_buf;
                isBubble_out := isBubble_buf;
                exception_data.carries_exception <= has_fault;
                exception_data.exception_code <= exception_code;
                exception_data.interrupted_pc <= programCounter_buf;
                exception_data.async_interrupt <= false;
                exception_data_set := has_fault;
            end if;
        end if;
        instructionToInstructionDecode <= instructionBuf;
        isBubble <= isBubble_out;
    end process;
end architecture;
