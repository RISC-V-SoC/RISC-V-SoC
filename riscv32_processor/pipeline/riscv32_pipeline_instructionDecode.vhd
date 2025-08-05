library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;
use work.riscv32_pkg.all;

entity riscv32_pipeline_instructionDecode is
    port (
        -- From/to instruction fetch: control
        overrideProgramCounter : out boolean;

        -- From instruction fetch: data
        instructionFromInstructionFetch : in riscv32_instruction_type;
        programCounter : in riscv32_address_type;

        -- Async exception input
        async_exception_pending : in boolean;
        async_exception_code : in riscv32_exception_code_type;

        -- To instruction fetch: data
        newProgramCounter : out riscv32_address_type;

        -- Data output
        registerControlWord : out riscv32_RegisterControlWord_type;
        executeControlWord : out riscv32_ExecuteControlWord_type;
        memoryControlWord : out riscv32_MemoryControlWord_type;
        writeBackControlWord : out riscv32_WriteBackControlWord_type;
        rs1Address : out riscv32_registerFileAddress_type;
        rs2Address : out riscv32_registerFileAddress_type;
        immidiate : out riscv32_data_type;
        uimmidiate : out riscv32_data_type;
        rdAddress : out riscv32_registerFileAddress_type;

        -- Error output
        exception_type : out riscv32_pipeline_exception_type;
        exception_code : out riscv32_exception_code_type
    );
end entity;

architecture behaviourial of riscv32_pipeline_instructionDecode is
    -- Control interaction
    signal decodedInstructionDecodeControlWord : riscv32_InstructionDecodeControlWord_type;
    signal decodedExecuteControlWord : riscv32_ExecuteControlWord_type;
    signal decodedMemoryControlWord : riscv32_MemoryControlWord_type;
    signal decodedWriteBackControlWord : riscv32_WriteBackControlWord_type;

    signal jumpTarget : riscv32_address_type;
    signal overrideProgramCounter_buf : boolean := false;
    signal illegal_instruction : boolean := false;
begin
    overrideProgramCounter <= decodedInstructionDecodeControlWord.jump;
    newProgramCounter <= jumpTarget;

    rs1Address <= to_integer(unsigned(instructionFromInstructionFetch(19 downto 15)));
    rs2Address <= to_integer(unsigned(instructionFromInstructionFetch(24 downto 20)));
    rdAddress <= to_integer(unsigned(instructionFromInstructionFetch(11 downto 7)));

    uimmidiate <= std_logic_vector(resize(unsigned(instructionFromInstructionFetch(19 downto 15)), uimmidiate'length));

    writeBackControlWord <= decodedWriteBackControlWord;
    memoryControlWord <= decodedMemoryControlWord;
    executeControlWord <= decodedExecuteControlWord;


    determineException : process(illegal_instruction, decodedInstructionDecodeControlWord, async_exception_pending, async_exception_code)
    begin
        exception_code <= riscv32_exception_code_illegal_instruction;
        if async_exception_pending then
            exception_type <= exception_async;
            exception_code <= async_exception_code;
        elsif illegal_instruction then
            exception_type <= exception_sync;
        elsif decodedInstructionDecodeControlWord.is_exception_return then
            exception_type <= exception_return;
        else
            exception_type <= exception_none;
        end if;
    end process;

    determineImmidiate : process(decodedInstructionDecodeControlWord, instructionFromInstructionFetch)
        variable immidiate_buf : riscv32_data_type := (others => '0');
        variable imm12 : std_logic_vector(11 downto 0) := (others => '0');
    begin
        case decodedInstructionDecodeControlWord.immidiate_type is
            when riscv32_i_immidiate =>
                immidiate_buf := std_logic_vector(resize(signed(instructionFromInstructionFetch(31 downto 20)), immidiate'length));
            when riscv32_u_immidiate =>
                immidiate_buf := (others => '0');
                immidiate_buf(31 downto 12) := instructionFromInstructionFetch(31 downto 12);
            when riscv32_b_immidiate =>
                imm12(11) := instructionFromInstructionFetch(31);
                imm12(10) := instructionFromInstructionFetch(7);
                imm12(9 downto 4) := instructionFromInstructionFetch(30 downto 25);
                imm12(3 downto 0) := instructionFromInstructionFetch(11 downto 8);
                immidiate_buf := std_logic_vector(resize(signed(imm12), immidiate_buf'length - 1)) & '0';
            when riscv32_s_immidiate =>
                imm12(11 downto 5) := instructionFromInstructionFetch(31 downto 25);
                imm12(4 downto 0) := instructionFromInstructionFetch(11 downto 7);
                immidiate_buf := std_logic_vector(resize(signed(imm12), immidiate_buf'length));
        end case;
        immidiate <= immidiate_buf;
    end process;


    determineJumpTarget : process(instructionFromInstructionFetch, programCounter)
        variable outputAddress : riscv32_address_type;
        variable jumpImmidiate : std_logic_vector(20 downto 0) := (others => '0');
        variable jumpOffset : signed(riscv32_instruction_type'range) := (others => '0');
    begin
        jumpImmidiate(20) := instructionFromInstructionFetch(31);
        jumpImmidiate(19 downto 12) := instructionFromInstructionFetch(19 downto 12);
        jumpImmidiate(11) := instructionFromInstructionFetch(20);
        jumpImmidiate(10 downto 1) := instructionFromInstructionFetch(30 downto 21);
        jumpImmidiate(0) := '0';

        jumpOffset := resize(signed(jumpImmidiate), jumpOffset'length);

        outputAddress := std_logic_vector(jumpOffset + signed(programCounter));
        jumpTarget <= outputAddress;
    end process;

    controlDecode : entity work.riscv32_control
    port map (
        instruction => instructionFromInstructionFetch,
        instructionDecodeControlWord => decodedInstructionDecodeControlWord,
        executeControlWord => decodedExecuteControlWord,
        memoryControlWord => decodedMemoryControlWord,
        writeBackControlWord => decodedWriteBackControlWord,
        registerControlWord => registerControlWord,
        illegal_instruction => illegal_instruction
    );

end architecture;
