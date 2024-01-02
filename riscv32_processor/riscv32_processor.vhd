library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;
use work.riscv32_pkg.all;

entity riscv32_processor is
    generic (
        startAddress : bus_address_type;
        clk_period : time;
        iCache_range : addr_range_type;
        iCache_word_count_log2b : natural;
        dCache_range : addr_range_type;
        dCache_word_count_log2b : natural
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        -- Control slave
        mst2control : in bus_mst2slv_type;
        control2mst : out bus_slv2mst_type;

        -- Instruction fetch master
        instructionFetch2slv : out bus_mst2slv_type;
        slv2instructionFetch : in bus_slv2mst_type;

        -- Memory master
        memory2slv : out bus_mst2slv_type;
        slv2memory : in bus_slv2mst_type
    );
end entity;

architecture behaviourial of riscv32_processor is
    signal pipelineStall : boolean;

    signal pipelineRst : std_logic;
    signal instructionAddress : riscv32_address_type;
    signal instruction : riscv32_instruction_type;
    signal dataAddress : riscv32_address_type;
    signal dataByteMask : riscv32_byte_mask_type;
    signal dataRead : boolean;
    signal dataWrite : boolean;
    signal dataToBus : riscv32_data_type;
    signal dataFromBus : riscv32_data_type;

    signal controllerReset : boolean;
    signal controllerStall : boolean;

    signal instructionFetchHasFault : boolean;
    signal instructionFetchFaultData : bus_fault_type;
    signal instructionStall : boolean;

    signal memoryHasFault : boolean;
    signal memoryFaultData : bus_fault_type;
    signal memoryStall : boolean;
    signal forbidBusInteraction : boolean;

    signal bus_slv_to_cpz_address : natural range 0 to 31;
    signal bus_slv_to_cpz_doWrite : boolean;
    signal bus_slv_to_cpz_data : riscv32_data_type;
    signal cpz_to_bus_slv_data : riscv32_data_type;

    signal pipeline_to_cpz_address : natural range 0 to 31 := 0;
    signal pipeline_to_cpz_doWrite : boolean := false;
    signal pipeline_to_cpz_data : riscv32_data_type := (others => 'X');
    signal cpz_to_pipeline_data : riscv32_data_type;

    signal bus_slv_to_regFile_address : natural range 0 to 31;
    signal bus_slv_to_regFile_doWrite : boolean;
    signal bus_slv_to_regFile_data : riscv32_data_type;
    signal regFile_to_bus_slv_data : riscv32_data_type;

begin
    pipelineStall <= controllerStall or instructionStall or memoryStall;
    forbidBusInteraction <= controllerReset or controllerStall;

    process(rst, controllerReset)
    begin
        if rst = '1' or controllerReset then
            pipelineRst <= '1';
        else
            pipelineRst <= '0';
        end if;
    end process;

    process(controllerStall, instructionStall)
    begin
    end process;

    pipeline : entity work.riscv32_pipeline
        generic map (
            startAddress => startAddress
        ) port map (
            clk => clk,
            rst => pipelineRst,
            stall => pipelineStall,
            instructionAddress => instructionAddress,
            instruction => instruction,
            dataAddress => dataAddress,
            dataByteMask => dataByteMask,
            dataRead => dataRead,
            dataWrite => dataWrite,
            dataOut => dataToBus,
            dataIn => dataFromBus,
            address_to_regFile => bus_slv_to_regFile_address,
            write_to_regFile => bus_slv_to_regFile_doWrite,
            data_to_regFile => bus_slv_to_regFile_data,
            data_from_regFile => regFile_to_bus_slv_data
        );

    bus_slave : entity work.riscv32_bus_slave
    port map (
        clk => clk,
        rst => rst,
        mst2slv => mst2control,
        slv2mst => control2mst,
        address_to_cpz => bus_slv_to_cpz_address,
        write_to_cpz => bus_slv_to_cpz_doWrite,
        data_to_cpz => bus_slv_to_cpz_data,
        data_from_cpz => cpz_to_bus_slv_data,
        address_to_regFile => bus_slv_to_regFile_address,
        write_to_regFile => bus_slv_to_regFile_doWrite,
        data_to_regFile => bus_slv_to_regFile_data,
        data_from_regFile => regFile_to_bus_slv_data
    );

    if2bus : entity work.riscv32_if2bus
    generic map (
        range_to_cache => iCache_range,
        cache_word_count_log2b => iCache_word_count_log2b
    ) port map (
        clk => clk,
        rst => rst,
        forbidBusInteraction => forbidBusInteraction,
        flushCache => controllerReset,
        mst2slv => instructionFetch2slv,
        slv2mst => slv2instructionFetch,
        hasFault => instructionFetchHasFault,
        faultData => instructionFetchFaultData,
        requestAddress => instructionAddress,
        instruction => instruction,
        stall => instructionStall
    );

    mem2bus : entity work.riscv32_mem2bus
    generic map (
        range_to_cache => dCache_range,
        cache_word_count_log2b => dCache_word_count_log2b
    ) port map (
        clk => clk,
        rst => rst,
        forbidBusInteraction => forbidBusInteraction,
        flushCache => controllerReset,
        mst2slv => memory2slv,
        slv2mst => slv2memory,
        hasFault => memoryHasFault,
        faultData => memoryFaultData,
        address => dataAddress,
        byteMask => dataByteMask,
        dataIn => dataToBus,
        dataOut => dataFromBus,
        doWrite => dataWrite,
        doRead => dataRead,
        stall => memoryStall
    );

    coprocessor_zero : entity work.riscv32_coprocessor_zero
    generic map (
        clk_period => clk_period
    ) port map (
        clk => clk,
        rst => rst,
        address_from_controller => bus_slv_to_cpz_address,
        address_from_pipeline => pipeline_to_cpz_address,
        write_from_controller => bus_slv_to_cpz_doWrite,
        write_from_pipeline => pipeline_to_cpz_doWrite,
        data_from_controller => bus_slv_to_cpz_data,
        data_from_pipeline => pipeline_to_cpz_data,
        data_to_controller => cpz_to_bus_slv_data,
        data_to_pipeline => cpz_to_pipeline_data,
        cpu_reset => controllerReset,
        cpu_stall => controllerStall
    );
end architecture;
