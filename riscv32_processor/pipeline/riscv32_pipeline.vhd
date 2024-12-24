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
        rst : in boolean;
        stall : in boolean;

        -- To/from instruction fetch unit
        instructionAddress : out riscv32_address_type;
        instruction : in riscv32_instruction_type;
        if_has_fault : in boolean;
        if_exception_code : in riscv32_exception_code_type;

        -- To/from data unit
        dataAddress : out riscv32_address_type;
        dataByteMask : out riscv32_byte_mask_type;
        dataRead : out boolean;
        dataWrite : out boolean;
        dataOut : out riscv32_data_type;
        dataIn : in riscv32_data_type;
        dataFault : in boolean;

        -- From/to bus slave
        address_to_regFile : in riscv32_registerFileAddress_type;
        write_to_regFile : in boolean;
        data_to_regFile : in riscv32_data_type;
        data_from_regFile : out riscv32_data_type;

        -- From/to control status register
        csr_out : out riscv32_to_csr_type;
        csr_in : in riscv32_from_csr_type;

        -- Exception data
        interrupt_vector_base_address : in riscv32_address_type;
        interrupt_return_address : in riscv32_address_type;
        interrupt_trigger : out boolean;
        interrupt_resolve : out boolean;
        interrupt_is_async : out boolean;
        exception_code : out riscv32_exception_code_type;
        interrupted_pc : out riscv32_address_type;

        instructionsRetiredCount : out unsigned(63 downto 0)
    );
end entity;

architecture behaviourial of riscv32_pipeline is
    -- Instruction fetch to instruction decode
    signal instructionToID : riscv32_instruction_type;
    signal programCounterFromIf : riscv32_address_type;
    signal isBubbleFromIF : boolean;
    signal exception_data_from_if : riscv32_exception_data_type;
    -- Instruction decode to instruction fetch
    signal overrideProgramCounterFromID : boolean;
    signal newProgramCounterFromID : riscv32_address_type;
    -- Branchhelper to IF
    signal injectBubbleFromBranchHelper : boolean;
    -- From ID
    signal regControlwordFromId : riscv32_RegisterControlWord_type;
    signal exControlWordFromId : riscv32_ExecuteControlWord_type;
    signal memControlWordFromId : riscv32_MemoryControlWord_type;
    signal wbControlWordFromId : riscv32_WriteBackControlWord_type;
    signal rs1AddressFromId : riscv32_registerFileAddress_type;
    signal rs2AddressFromId : riscv32_registerFileAddress_type;
    signal immidiateFromId : riscv32_data_type;
    signal uimmidiateFromId : riscv32_data_type;
    signal rdAddressFromId : riscv32_registerFileAddress_type;
    signal exceptionTypeFromId : riscv32_pipeline_exception_type;
    signal exceptionCodeFromId : riscv32_exception_code_type;
    -- Registerfile to register stage
    signal rs1DataFromRegFile : riscv32_data_type;
    signal rs2DataFromRegFile : riscv32_data_type;
    -- From id/reg
    signal requiresServiceFromIdReg : boolean;
    signal regControlwordFromIdReg : riscv32_RegisterControlWord_type;
    signal exControlWordFromIdReg : riscv32_ExecuteControlWord_type;
    signal memControlWordFromIdReg : riscv32_MemoryControlWord_type;
    signal wbControlWordFromIdReg : riscv32_WriteBackControlWord_type;
    signal isBubbleFromIdReg : boolean;
    signal exception_data_from_idreg : riscv32_exception_data_type;
    signal programCounterFromIdReg : riscv32_address_type;
    signal rs1DataFromIdReg : riscv32_data_type;
    signal rs1AddressFromIdReg : riscv32_registerFileAddress_type;
    signal rs2DataFromIdReg : riscv32_data_type;
    signal rs2AddressFromIdReg : riscv32_registerFileAddress_type;
    signal immidiateFromIdReg : riscv32_data_type;
    signal uimmidiateFromIdReg : riscv32_data_type;
    signal rdAddrFromIdReg : riscv32_registerFileAddress_type;
    -- From Reg
    signal rs1DataFromReg : riscv32_data_type;
    signal rs2DataFromReg : riscv32_data_type;
    signal repeatInstructionFromReg : boolean;
    -- From reg/ex
    signal requiresServiceFromRegEx : boolean;
    signal exControlWordFromRegEx : riscv32_ExecuteControlWord_type;
    signal memControlWordFromRegEx : riscv32_MemoryControlWord_type;
    signal wbControlWordFromRegEx : riscv32_WriteBackControlWord_type;
    signal isBubbleFromRegEx : boolean;
    signal exception_data_from_regex : riscv32_exception_data_type;
    signal programCounterFromRegEx : riscv32_address_type;
    signal rs1DataFromRegEx : riscv32_data_type;
    signal rs1AddressFromRegEx : riscv32_registerFileAddress_type;
    signal rs2DataFromRegEx : riscv32_data_type;
    signal rs2AddressFromRegEx : riscv32_registerFileAddress_type;
    signal immidiateFromRegEx : riscv32_data_type;
    signal uimmidiateFromRegEx : riscv32_data_type;
    signal rdAddrFromRegEx : riscv32_registerFileAddress_type;
    -- Execute to memory
    signal execResFromExec : riscv32_data_type;
    -- From ex/mem
    signal requiresServiceFromExMem : boolean;
    signal memControlWordFromExMem : riscv32_MemoryControlWord_type;
    signal wbControlWordFromExMem : riscv32_WriteBackControlWord_type;
    signal isBubbleFromExMem : boolean;
    signal exception_data_from_exmem : riscv32_exception_data_type;
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
    signal exceptionTypeFromMem : riscv32_pipeline_exception_type;
    signal exceptionCodeFromMem : riscv32_exception_code_type;
    -- From mem/wb
    signal wbControlWordFromMemWb : riscv32_WriteBackControlWord_type;
    signal isBubbleFromMemWb : boolean;
    signal exception_data_from_memwb : riscv32_exception_data_type;
    signal execResFromMemWb : riscv32_data_type;
    signal memDataFromMemWb : riscv32_data_type;
    signal rdAddressFromMemWb : riscv32_registerFileAddress_type;
    -- From writeback
    signal regWriteFromWb : boolean;
    signal regWriteAddrFromWb : riscv32_registerFileAddress_type;
    signal regWriteDataFromWb : riscv32_data_type;

    signal stallToResolveHazard : boolean;
    signal nopOutputToResolveHazard : boolean;

    signal handle_exception : boolean;
    signal exception_trigger_buf : boolean;
    signal exception_resolve_buf : boolean;
    signal programCounterFromExceptionHandler : riscv32_address_type;

begin
    interrupt_trigger <= exception_trigger_buf;
    interrupt_resolve <= exception_resolve_buf;
    handle_exception <= exception_trigger_buf or exception_resolve_buf;

    stallToResolveHazard <= stall or repeatInstructionFromReg;
    nopOutputToResolveHazard <= not stall and repeatInstructionFromReg;

    -- IF stage
    instructionFetch : entity work.riscv32_pipeline_instructionFetch
    generic map (
        startAddress
    ) port map (
        clk => clk,
        rst => rst,

        requestFromBusAddress => instructionAddress,
        instructionFromBus => instruction,
        has_fault => if_has_fault or requiresServiceFromIdReg,
        exception_code => if_exception_code,

        isBubble => isBubbleFromIF,

        instructionToInstructionDecode => instructionToID,
        programCounter => programCounterFromIf,
        exception_data => exception_data_from_if,

        overrideProgramCounterFromID => overrideProgramCounterFromID,
        newProgramCounterFromID => newProgramCounterFromID,

        overrideProgramCounterFromEx => overrideProgramCounterFromEx,
        newProgramCounterFromEx => newProgramCounterFromEx,

        overrideProgramCounterFromInterrupt => handle_exception,
        newProgramCounterFromInterrupt => programCounterFromExceptionHandler,

        injectBubble => injectBubbleFromBranchHelper,
        stall => stallToResolveHazard
    );

    branchHelper : entity work.riscv32_pipeline_branchHelper
    generic map (
        array_size => 2
    ) port map (
        executeControlWords(0) => exControlWordFromId,
        executeControlWords(1) => exControlWordFromIdReg,
        injectBubble => injectBubbleFromBranchHelper
    );


    -- ID stage
    instructionDecode : entity work.riscv32_pipeline_instructionDecode
    port map (
        overrideProgramCounter => overrideProgramCounterFromID,

        instructionFromInstructionFetch => instructionToID,
        programCounter => programCounterFromIf,

        newProgramCounter => newProgramCounterFromID,

        registerControlWord => regControlwordFromId,
        executeControlWord => exControlWordFromId,
        memoryControlWord => memControlWordFromId,
        writeBackControlWord => wbControlWordFromId,
        rs1Address => rs1AddressFromId,
        rs2Address => rs2AddressFromId,
        immidiate => immidiateFromId,
        uimmidiate => uimmidiateFromId,
        rdAddress => rdAddressFromId,

        exception_type => exceptionTypeFromId,
        exception_code => exceptionCodeFromId
    );

    idregReg : entity work.riscv32_pipeline_stageRegister
    port map (
        clk => clk,
        -- Control in
        stall => stall or stallToResolveHazard,
        rst => rst or handle_exception,
        -- Control out
        requires_service => requiresServiceFromIdReg,
        -- Exception data in
        exception_data_in => exception_data_from_if,
        exception_from_stage => exceptionTypeFromId,
        exception_from_stage_code => exceptionCodeFromId,
        force_service_request => requiresServiceFromRegEx,
        -- Pipeline control in
        registerControlWordIn => regControlwordFromId,
        executeControlWordIn => exControlWordFromId,
        memoryControlWordIn => memControlWordFromId,
        writeBackControlWordIn => wbControlWordFromId,
        -- Pipeline data in
        isBubbleIn => isBubbleFromIF,
        programCounterIn => programCounterFromIf,
        rs1AddressIn => rs1AddressFromId,
        rs2AddressIn => rs2AddressFromId,
        immidiateIn => immidiateFromId,
        uimmidiateIn => uimmidiateFromId,
        rdAddressIn => rdAddressFromId,
        -- Exception data out
        exception_data_out => exception_data_from_idreg,
        -- Pipeline control out
        registerControlWordOut => regControlwordFromIdReg,
        executeControlWordOut => exControlWordFromIdReg,
        memoryControlWordOut => memControlWordFromIdReg,
        writeBackControlWordOut => wbControlWordFromIdReg,
        -- Pipeline data out
        isBubbleOut => isBubbleFromIdReg,
        programCounterOut => programCounterFromIdReg,
        rs1AddressOut => rs1AddressFromIdReg,
        rs2AddressOut => rs2AddressFromIdReg,
        immidiateOut => immidiateFromIdReg,
        uimmidiateOut => uimmidiateFromIdReg,
        rdAddressOut => rdAddrFromIdReg
    );

    -- Register stage
    RegisterStage : entity work.riscv32_pipeline_register
    port map (
        repeatInstruction => repeatInstructionFromReg,
        registerControlWord => regControlwordFromIdReg,
        execControlWord => exControlWordFromIdReg,
        writeBackControlWord => wbControlWordFromIdReg,
        regExWriteBackControlWord => wbControlWordFromRegEx,
        exMemWriteBackControlWord => wbControlWordFromExMem,
        regExRdAddress => rdAddrFromRegEx,
        exMemRdAddress => rdAddrFromExMem,
        exMemExecResult => execResFromExMem,
        rs1Address => rs1AddressFromIdReg,
        rs2Address => rs2AddressFromIdReg,
        rs1DataFromRegFile => rs1DataFromRegFile,
        rs2DataFromRegFile => rs2DataFromRegFile,
        rs1DataOut => rs1DataFromReg,
        rs2DataOut => rs2DataFromReg
    );

    registerFile : entity work.riscv32_pipeline_registerFile
    port map (
        clk => clk,
        readPortOneAddress => rs1AddressFromIdReg,
        readPortOneData => rs1DataFromRegFile,
        readPortTwoAddress => rs2AddressFromIdReg,
        readPortTwoData => rs2DataFromRegFile,
        writePortDoWrite => regWriteFromWb,
        writePortAddress => regWriteAddrFromWb,
        writePortData => regWriteDataFromWb,
        extPortAddress => address_to_regFile,
        readPortExtData => data_from_regFile,
        writePortExtDoWrite => write_to_regFile,
        writePortExtData => data_to_regFile
    );

    regexReg : entity work.riscv32_pipeline_stageRegister
    port map (
        clk => clk,
        -- Control in
        stall => stall,
        rst => rst or handle_exception or nopOutputToResolveHazard,
        -- Control out
        requires_service => requiresServiceFromRegEx,
        -- Exception data in
        exception_data_in => exception_data_from_idreg,
        force_service_request => requiresServiceFromExMem,
        -- Pipeline control in
        executeControlWordIn => exControlWordFromIdReg,
        memoryControlWordIn => memControlWordFromIdReg,
        writeBackControlWordIn => wbControlWordFromIdReg,
        -- Pipeline data in
        isBubbleIn => isBubbleFromIdReg,
        programCounterIn => programCounterFromIdReg,
        rs1DataIn => rs1DataFromReg,
        rs2DataIn => rs2DataFromReg,
        immidiateIn => immidiateFromIdReg,
        uimmidiateIn => uimmidiateFromIdReg,
        rdAddressIn => rdAddrFromIdReg,
        -- Exception data out
        exception_data_out => exception_data_from_regex,
        -- Pipeline control out
        executeControlWordOut => exControlWordFromRegEx,
        memoryControlWordOut => memControlWordFromRegEx,
        writeBackControlWordOut => wbControlWordFromRegEx,
        -- Pipeline data out
        isBubbleOut => isBubbleFromRegEx,
        programCounterOut => programCounterFromRegEx,
        rs1DataOut => rs1DataFromRegEx,
        rs2DataOut => rs2DataFromRegEx,
        immidiateOut => immidiateFromRegEx,
        uimmidiateOut => uimmidiateFromRegEx,
        rdAddressOut => rdAddrFromRegEx
    );

    -- EX stage
    execute : entity work.riscv32_pipeline_execute
    port map (
        executeControlWord => exControlWordFromRegEx,

        rs1Data => rs1DataFromRegEx,
        rs2Data => rs2DataFromRegEx,
        immidiate => immidiateFromRegEx,
        programCounter => programCounterFromRegEx,

        execResult => execResFromExec,

        overrideProgramCounter => overrideProgramCounterFromEx,
        newProgramCounter => newProgramCounterFromEx
    );

    exMemReg : entity work.riscv32_pipeline_stageRegister
    port map (
       clk => clk,

       stall => stall,
       rst => rst or handle_exception,

       requires_service => requiresServiceFromExMem,

       exception_data_in => exception_data_from_regex,
       force_service_request => exceptionTypeFromMem /= exception_none,

       memoryControlWordIn => memControlWordFromRegEx,
       writeBackControlWordIn => wbControlWordFromRegEx,

       isBubbleIn => isBubbleFromRegEx,
       execResultIn => execResFromExec,
       rs1DataIn => rs1DataFromRegEx,
       rs2DataIn => rs2DataFromRegEx,
       rdAddressIn => rdAddrFromRegEx,
       uimmidiateIn => uimmidiateFromRegEx,

       exception_data_out => exception_data_from_exmem,

       memoryControlWordOut => memControlWordFromExMem,
       writeBackControlWordOut => wbControlWordFromExMem,

       isBubbleOut => isBubbleFromExMem,
       execResultOut => execResFromExMem,
       rs1DataOut => rs1DataFromExMem,
       rs2DataOut => rs2DataFromExMem,
       rdAddressOut => rdAddrFromExMem,
       uimmidiateOut => uimmidiateFromExMem
    );

    -- MEM stage
    memory : entity work.riscv32_pipeline_memory
    port map (
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
        faultFromMem => dataFault,

        csrOut => csr_out,
        csr_in => csr_in,
        exception_type => exceptionTypeFromMem,
        exception_code => exceptionCodeFromMem
    );

    memWbReg : entity work.riscv32_pipeline_stageRegister
    port map (
       clk => clk,

       stall => stall,
       rst => rst or handle_exception,

       exception_data_in => exception_data_from_exmem,
       exception_from_stage => exceptionTypeFromMem,
       exception_from_stage_code => exceptionCodeFromMem,

       writeBackControlWordIn => wbControlWordFromExMem,

       isBubbleIn => isBubbleFromExMem,
       execResultIn => execResFromExMem,
       memDataReadIn => memDataFromMem,
       rdAddressIn => rdAddrFromExMem,

       exception_data_out => exception_data_from_memwb,

       writeBackControlWordOut => wbControlWordFromMemWb,

       isBubbleOut => isBubbleFromMemWb,
       execResultOut => execResFromMemWb,
       memDataReadOut => memDataFromMemWb,
       rdAddressOut => rdAddressFromMemWb
   );

    -- WB stage
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

    instructionsRetiredCounter : entity work.riscv32_pipeline_instructionsRetiredCounter
    port map (
        clk => clk,
        rst => rst,
        stall => stall,
        isBubble => isBubbleFromMemWb,
        instructionsRetiredCount => instructionsRetiredCount
    );

    exception_handler : entity work.riscv32_pipeline_exception_handler
    generic map (
        propagation_delay => 2
    ) port map (
        clk => clk,
        rst => rst,
        exception_data_in => exception_data_from_memwb,
        exception_vector_base_address => interrupt_vector_base_address,
        exception_return_address => interrupt_return_address,
        address_to_instruction_fetch => programCounterFromExceptionHandler,
        exception_trigger => exception_trigger_buf,
        exception_resolved => exception_resolve_buf,
        exception_code => exception_code,
        interrupted_pc => interrupted_pc,
        interrupt_is_async => interrupt_is_async
    );

end architecture;
