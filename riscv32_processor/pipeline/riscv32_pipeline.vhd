library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_pipeline is
    generic (
        startAddress : riscv32_address_type
    );
    port (
        clk : in std_logic;
        rst : in std_logic;
        stall : in boolean;

        instructionAddress : out riscv32_address_type;
        instruction : in riscv32_instruction_type;

        dataAddress : out riscv32_address_type;
        dataByteMask : out riscv32_byte_mask_type;
        dataRead : out boolean;
        dataWrite : out boolean;
        dataOut : out riscv32_data_type;
        dataIn : in riscv32_data_type;

        -- From/to bus slave
        address_to_regFile : in riscv32_registerFileAddress_type;
        write_to_regFile : in boolean;
        data_to_regFile : in riscv32_data_type;
        data_from_regFile : out riscv32_data_type;

        -- From/to control status register
        csr_out : out riscv32_to_csr_type;
        csr_data : in riscv32_data_type;

        instructionsRetiredCount : out unsigned(63 downto 0)
    );
end entity;

architecture behaviourial of riscv32_pipeline is
    -- Instruction fetch to instruction decode
    signal instructionToID : riscv32_instruction_type;
    signal programCounterFromIf : riscv32_address_type;
    signal isBubbleFromIF : boolean;
    -- Instruction decode to instruction fetch
    signal overrideProgramCounterFromID : boolean;
    signal newProgramCounterFromID : riscv32_address_type;
    signal repeatInstruction : boolean;
    -- Branchhelper to IF
    signal injectBubbleFromBranchHelper : boolean;
    -- Instruction decode to id/ex
    signal nopOutputFromId : boolean;
    signal nopOutputToIdEx : boolean;
    signal exControlWordFromId : riscv32_ExecuteControlWord_type;
    signal memControlWordFromId : riscv32_MemoryControlWord_type;
    signal wbControlWordFromId : riscv32_WriteBackControlWord_type;
    signal rs1AddressFromId : riscv32_registerFileAddress_type;
    signal rs2AddressFromId : riscv32_registerFileAddress_type;
    signal immidiateFromId : riscv32_data_type;
    signal uimmidiateFromId : riscv32_data_type;
    signal rdAddressFromId : riscv32_registerFileAddress_type;
    -- Registerfile to id/ex
    signal rs1DataFromRegFile : riscv32_data_type;
    signal rs2DataFromRegFile : riscv32_data_type;
    -- From id/ex
    signal exControlWordFromIdEx : riscv32_ExecuteControlWord_type;
    signal memControlWordFromIdEx : riscv32_MemoryControlWord_type;
    signal wbControlWordFromIdEx : riscv32_WriteBackControlWord_type;
    signal isBubbleFromIdEx : boolean;
    signal programCounterFromIdEx : riscv32_address_type;
    signal rs1DataFromIdEx : riscv32_data_type;
    signal rs1AddressFromIdEx : riscv32_registerFileAddress_type;
    signal rs2DataFromIdEx : riscv32_data_type;
    signal rs2AddressFromIdEx : riscv32_registerFileAddress_type;
    signal immidiateFromIdEx : riscv32_data_type;
    signal uimmidiateFromIdEx : riscv32_data_type;
    signal rdAddrFromIdEx : riscv32_registerFileAddress_type;
    -- Instruction decode to forwarding
    signal rs1DataToFwU : riscv32_data_type;
    signal rs1AddressToFwU : riscv32_registerFileAddress_type;
    signal rs2DataToFwU : riscv32_data_type;
    signal rs2AddressToFwU : riscv32_registerFileAddress_type;
    -- Instruction decode to loadHazardDetector
    signal portOneAddrToLHD : riscv32_registerFileAddress_type;
    signal portTwoAddrToLHD : riscv32_registerFileAddress_type;
    -- loadHazardDetector to ID
    signal loadHazardDetected : boolean;
    -- Forwarding unit to execute
    signal rs1DataFromFwu : riscv32_data_type;
    signal rs2DataFromFwu : riscv32_data_type;
    -- Execute to memory
    signal execResFromExec : riscv32_data_type;
    -- From ex/mem
    signal memControlWordFromExMem : riscv32_MemoryControlWord_type;
    signal wbControlWordFromExMem : riscv32_WriteBackControlWord_type;
    signal isBubbleFromExMem : boolean;
    signal execResFromExMem : riscv32_data_type;
    signal rs1DataFromExMem : riscv32_data_type;
    signal rs2DataFromExMem : riscv32_data_type;
    signal uimmidiateFromExMem : riscv32_data_type;
    signal rdAddrFromExMem : riscv32_registerFileAddress_type;
    -- Execute to instruction fetch
    signal overrideProgramCounterFromEx : boolean;
    signal newProgramCounterFromEx : riscv32_address_type;
    -- From memory
    signal memDataFromMem : riscv32_data_type;
    signal cpzDataFromMem : riscv32_data_type;
    -- From mem/wb
    signal wbControlWordFromMemWb : riscv32_WriteBackControlWord_type;
    signal isBubbleFromMemWb : boolean;
    signal execResFromMemWb : riscv32_data_type;
    signal memDataFromMemWb : riscv32_data_type;
    signal rdAddressFromMemWb : riscv32_registerFileAddress_type;
    -- From writeback
    signal regWriteFromWb : boolean;
    signal regWriteAddrFromWb : riscv32_registerFileAddress_type;
    signal regWriteDataFromWb : riscv32_data_type;

    signal instructionFetchStall : boolean;

begin
    instructionFetchStall <= stall or repeatInstruction;
    nopOutputToIdEx <= not stall and nopOutputFromId;

    instructionFetch : entity work.riscv32_pipeline_instructionFetch
    generic map (
        startAddress
    ) port map (
        clk => clk,
        rst => rst,

        requestFromBusAddress => instructionAddress,
        instructionFromBus => instruction,
        isBubble => isBubbleFromIF,

        instructionToInstructionDecode => instructionToID,
        programCounter => programCounterFromIf,

        overrideProgramCounterFromID => overrideProgramCounterFromID,
        newProgramCounterFromID => newProgramCounterFromID,

        overrideProgramCounterFromEx => overrideProgramCounterFromEx,
        newProgramCounterFromEx => newProgramCounterFromEx,

        injectBubble => injectBubbleFromBranchHelper,
        stall => instructionFetchStall
    );

    instructionDecode : entity work.riscv32_pipeline_instructionDecode
    port map (
        overrideProgramCounter => overrideProgramCounterFromID,
        repeatInstruction => repeatInstruction,

        instructionFromInstructionFetch => instructionToID,
        programCounter => programCounterFromIf,

        newProgramCounter => newProgramCounterFromID,

        nopOutput => nopOutputFromId,

        executeControlWord => exControlWordFromId,
        memoryControlWord => memControlWordFromId,
        writeBackControlWord => wbControlWordFromId,
        rs1Address => rs1AddressFromId,
        rs2Address => rs2AddressFromId,
        immidiate => immidiateFromId,
        uimmidiate => uimmidiateFromId,
        rdAddress => rdAddressFromId,

        loadHazardDetected => loadHazardDetected
    );

    idexReg : entity work.riscv32_pipeline_idexRegister
    port map (
        clk => clk,
        -- Control in
        stall => stall,
        nop => nopOutputToIdEx or rst = '1',
        -- Pipeline control in
        executeControlWordIn => exControlWordFromId,
        memoryControlWordIn => memControlWordFromId,
        writeBackControlWordIn => wbControlWordFromId,
        -- Pipeline data in
        isBubbleIn => isBubbleFromIF,
        programCounterIn => programCounterFromIf,
        rs1DataIn => rs1DataFromRegFile,
        rs1AddressIn => rs1AddressFromId,
        rs2DataIn => rs2DataFromRegFile,
        rs2AddressIn => rs2AddressFromId,
        immidiateIn => immidiateFromId,
        uimmidiateIn => uimmidiateFromId,
        rdAddressIn => rdAddressFromId,
        -- Pipeline control out
        executeControlWordOut => exControlWordFromIdEx,
        memoryControlWordOut => memControlWordFromIdEx,
        writeBackControlWordOut => wbControlWordFromIdEx,
        -- Pipeline data out
        isBubbleOut => isBubbleFromIdEx,
        programCounterOut => programCounterFromIdEx,
        rs1DataOut => rs1DataFromIdEx,
        rs1AddressOut => rs1AddressFromIdEx,
        rs2DataOut => rs2DataFromIdEx,
        rs2AddressOut => rs2AddressFromIdEx,
        immidiateOut => immidiateFromIdEx,
        uimmididateOut => uimmidiateFromIdEx,
        rdAddressOut => rdAddrFromIdEx
    );

    execute : entity work.riscv32_pipeline_execute
    port map (
        executeControlWord => exControlWordFromIdEx,

        rs1Data => rs1DataFromFwu,
        rs2Data => rs2DataFromFwu,
        immidiate => immidiateFromIdEx,
        programCounter => programCounterFromIdEx,

        execResult => execResFromExec,

        overrideProgramCounter => overrideProgramCounterFromEx,
        newProgramCounter => newProgramCounterFromEx
    );

    exMemReg : entity work.riscv32_pipeline_exmemRegister
    port map (
       clk => clk,

       stall => stall,
       nop => rst = '1',

       memoryControlWordIn => memControlWordFromIdEx,
       writeBackControlWordIn => wbControlWordFromIdEx,

       isBubbleIn => isBubbleFromIdEx,
       execResultIn => execResFromExec,
       rs1DataIn => rs1DataFromFwu,
       rs2DataIn => rs2DataFromFwu,
       rdAddressIn => rdAddrFromIdEx,
       uimmidiateIn => uimmidiateFromIdEx,

       memoryControlWordOut => memControlWordFromExMem,
       writeBackControlWordOut => wbControlWordFromExMem,

       isBubbleOut => isBubbleFromExMem,
       execResultOut => execResFromExMem,
       rs1DataOut => rs1DataFromExMem,
       rs2DataOut => rs2DataFromExMem,
       rdAddressOut => rdAddrFromExMem,
       uimmididateOut => uimmidiateFromExMem
   );

    memory : entity work.riscv32_pipeline_memory
    port map (
        stall => stall,

        memoryControlWord => memControlWordFromExMem,

        requestAddress => execResFromExMem,
        rs1Data => rs1DataFromExMem,
        rs2Data => rs2DataFromExMem,
        uimmidiate => uimmidiateFromExMem,

        memDataRead => memDataFromMem,

        doMemRead => dataRead,
        doMemWrite => dataWrite,
        memAddress => dataAddress,
        memByteMask => dataByteMask,
        dataToMem => dataOut,
        dataFromMem => dataIn,
        csrOut => csr_out,
        csrReadData => csr_data
    );

    memWbReg : entity work.riscv32_pipeline_memwbRegister
    port map (
       clk => clk,

       stall => stall,
       nop => rst = '1',

       writeBackControlWordIn => wbControlWordFromExMem,

       isBubbleIn => isBubbleFromExMem,
       execResultIn => execResFromExMem,
       memDataReadIn => memDataFromMem,
       rdAddressIn => rdAddrFromExMem,

       writeBackControlWordOut => wbControlWordFromMemWb,

       isBubbleOut => isBubbleFromMemWb,
       execResultOut => execResFromMemWb,
       memDataReadOut => memDataFromMemWb,
       rdAddressOut => rdAddressFromMemWb
   );

    writeBack : entity work.riscv32_pipeline_writeBack
    port map (
        writeBackControlWord => wbControlWordFromMemWb,

        execResult => execResFromMemWb,
        memDataRead => memDataFromMemWb,
        rdAddress => rdAddressFromMemWb,

        regWrite => regWriteFromWb,
        regWriteAddress => regWriteAddrFromWb,
        regWriteData => regWriteDataFromWb
    );

    -- Lives in EX stage
    forwarding_unit : entity work.riscv32_pipeline_forwarding_unit
    port map (
        rs1DataFromID => rs1DataFromIdEx,
        rs1AddressFromID => rs1AddressFromIdEx,
        rs2DataFromID => rs2DataFromIdEx,
        rs2AddressFromID => rs2AddressFromIdEx,

        regDataFromEx => execResFromExMem,
        regAddressFromEx => rdAddrFromExMem,
        regWriteFromEx => wbControlWordFromExMem.regWrite,

        regDataFromMem => regWriteDataFromWb,
        regAddressFromMem => regWriteAddrFromWb,
        regWriteFromMem => regWriteFromWb,

        rs1Data => rs1DataFromFwu,
        rs2Data => rs2DataFromFwu
    );

    -- Lives in ID stage
    loadHazardDetector : entity work.riscv32_pipeline_loadHazardDetector
    port map (
        writeBackControlWordFromEx => wbControlWordFromIdEx,
        targetRegFromEx => rdAddrFromIdEx,
        readPortOneAddressFromID => rs2AddressFromId,
        readPortTwoAddressFromID => rs1AddressFromId,
        loadHazardDetected => loadHazardDetected
    );

    -- Lives in ID stage
    registerFile : entity work.riscv32_pipeline_registerFile
    port map (
        clk => clk,
        readPortOneAddress => rs1AddressFromId,
        readPortOneData => rs1DataFromRegFile,
        readPortTwoAddress => rs2AddressFromId,
        readPortTwoData => rs2DataFromRegFile,
        writePortDoWrite => regWriteFromWb,
        writePortAddress => regWriteAddrFromWb,
        writePortData => regWriteDataFromWb,
        extPortAddress => address_to_regFile,
        readPortExtData => data_from_regFile,
        writePortExtDoWrite => write_to_regFile,
        writePortExtData => data_to_regFile
    );

    branchHelper : entity work.riscv32_pipeline_branchHelper
    generic map (
        array_size => 1
    ) port map (
        executeControlWords(0) => exControlWordFromId,
        injectBubble => injectBubbleFromBranchHelper
    );

    instructionsRetiredCounter : entity work.riscv32_pipeline_instructionsRetiredCounter
    port map (
        clk => clk,
        rst => rst,
        stall => stall,
        isBubble => isBubbleFromMemWb,
        instructionsRetiredCount => instructionsRetiredCount
    );

end architecture;
