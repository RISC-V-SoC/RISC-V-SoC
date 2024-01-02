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
        rst : in std_logic;

        -- To bus controller
        requestFromBusAddress : out riscv32_address_type;
        instructionFromBus : in riscv32_instruction_type;

        -- To instructionDecode
        instructionToInstructionDecode : out riscv32_instruction_type;
        programCounter : out riscv32_address_type;

        -- From instructionDecode (unconditional jump)
        overrideProgramCounterFromID : in boolean;
        newProgramCounterFromID : in riscv32_address_type;

        -- From execute (unconditional jump or branch)
        overrideProgramCounterFromEx : in boolean;
        newProgramCounterFromEx : in riscv32_address_type;

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
begin

    requestFromBusAddress <= programCounter_buf;

    determineProgramCounterPlusFour : process(programCounter_buf)
    begin
        programCounterPlusFour <= std_logic_vector(unsigned(programCounter_buf) + 4);
    end process;

    determineNextProgramCounter : process(overrideProgramCounterFromID, newProgramCounterFromID, overrideProgramCounterFromEx,
                                          newProgramCounterFromEx, programCounterPlusFour)
    begin
        if overrideProgramCounterFromEx then
            nextProgramCounter <= newProgramCounterFromEx;
        elsif overrideProgramCounterFromID then
            nextProgramCounter <= newProgramCounterFromID;
        else
            nextProgramCounter <= programCounterPlusFour;
        end if;
    end process;

    programCounterControl : process(clk)
    begin
        if rising_edge(clk) then
            outputNop <= false;
            if rst = '1' then
                programCounter_buf <= startAddress;
            elsif stall then
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
            instructionToInstructionDecode_buf <= riscv32_instructionNop;
            currentInstructionTransfersControl <= false;
        else
            instructionToInstructionDecode_buf <= instructionFromBus;
            currentInstructionTransfersControl <= instructionFromBus(6 downto 4) = "110";
        end if;
    end process;

    IFIDRegs : process(clk)
        variable instructionBuf : riscv32_instruction_type := riscv32_instructionNop;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                instructionBuf := riscv32_instructionNop;
            elsif not stall then
                instructionBuf := instructionToInstructionDecode_buf;
                programCounter <= programCounter_buf;
            end if;
        end if;
        instructionToInstructionDecode <= instructionBuf;
    end process;
end architecture;
