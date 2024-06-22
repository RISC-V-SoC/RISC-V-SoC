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
        rst : in boolean;

        -- Control slave
        mst2control : in bus_mst2slv_type;
        control2mst : out bus_slv2mst_type;

        -- Instruction fetch master
        instructionFetch2slv : out bus_mst2slv_type;
        slv2instructionFetch : in bus_slv2mst_type;

        -- Memory master
        memory2slv : out bus_mst2slv_type;
        slv2memory : in bus_slv2mst_type;

        reset_request : out boolean
    );
end entity;

architecture behaviourial of riscv32_processor is
    signal pipelineStall : boolean;

    signal instructionAddress : riscv32_address_type;
    signal instruction : riscv32_instruction_type;
    signal dataAddress : riscv32_address_type;
    signal dataByteMask : riscv32_byte_mask_type;
    signal dataRead : boolean;
    signal dataWrite : boolean;
    signal dataToBus : riscv32_data_type;
    signal dataFromBus : riscv32_data_type;

    signal controllerStall : boolean;

    signal instructionFetchHasFault : boolean;
    signal instructionFetchFaultData : bus_fault_type;
    signal instructionStall : boolean;

    signal memoryHasFault : boolean;
    signal memoryFaultData : bus_fault_type;
    signal memoryStall : boolean;
    signal forbidBusInteraction : boolean;

    signal bus_slv_to_ci_address : natural range 0 to 31;
    signal bus_slv_to_ci_doWrite : boolean;
    signal bus_slv_to_ci_data : riscv32_data_type;
    signal ci_to_bus_slv_data : riscv32_data_type;

    signal bus_slv_to_regFile_address : natural range 0 to 31;
    signal bus_slv_to_regFile_doWrite : boolean;
    signal bus_slv_to_regFile_data : riscv32_data_type;
    signal regFile_to_bus_slv_data : riscv32_data_type;

    signal pipeline_to_csr : riscv32_to_csr_type;
    signal csr_to_pipeline : riscv32_data_type;

    signal cycleCounter_value : unsigned(63 downto 0);
    signal systemtimer_value : unsigned(63 downto 0);
    signal instructionsRetired_value : unsigned(63 downto 0);

    signal address_to_unprivileged_counter_timers : natural range 0 to 31;
    signal read_high_to_unprivileged_counter_timers : boolean;
    signal read_data_from_unprivileged_counter_timers : riscv32_data_type := (others => '0');
    signal error_from_unprivileged_counter_timers : boolean := false;
begin
    pipelineStall <= controllerStall or instructionStall or memoryStall;
    forbidBusInteraction <= controllerStall;

    pipeline : entity work.riscv32_pipeline
        generic map (
            startAddress => startAddress
        ) port map (
            clk => clk,
            rst => rst,
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
            data_from_regFile => regFile_to_bus_slv_data,
            csr_out => pipeline_to_csr,
            csr_data => csr_to_pipeline,
            instructionsRetiredCount => instructionsRetired_value
        );

    bus_slave : entity work.riscv32_bus_slave
    port map (
        clk => clk,
        rst => rst,
        mst2slv => mst2control,
        slv2mst => control2mst,
        address_to_ci => bus_slv_to_ci_address,
        write_to_ci => bus_slv_to_ci_doWrite,
        data_to_ci => bus_slv_to_ci_data,
        data_from_ci => ci_to_bus_slv_data,
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
        flushCache => rst,
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
        flushCache => rst,
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

    control_interface : entity work.riscv32_control_interface
    generic map (
        clk_period => clk_period
    ) port map (
        clk => clk,
        rst => rst,
        address_from_controller => bus_slv_to_ci_address,
        write_from_controller => bus_slv_to_ci_doWrite,
        data_from_controller => bus_slv_to_ci_data,
        data_to_controller => ci_to_bus_slv_data,
        instructionAddress => instructionAddress,
        if_fault => instructionFetchHasFault,
        if_faultData => instructionFetchFaultData,
        mem_fault => memoryHasFault,
        mem_faultData => memoryFaultData,
        cpu_reset => reset_request,
        cpu_stall => controllerStall
    );

    csr : entity work.riscv32_csr
    port map (
        csr_in => pipeline_to_csr,
        read_data => csr_to_pipeline,
        address_to_unprivileged_counter_timers => address_to_unprivileged_counter_timers,
        read_high_to_unprivileged_counter_timers => read_high_to_unprivileged_counter_timers,
        read_data_from_unprivileged_counter_timers => read_data_from_unprivileged_counter_timers,
        error_from_unprivileged_counter_timers => error_from_unprivileged_counter_timers
    );

    csr_unpriviledged_counter_timers : entity work.riscv32_csr_unprivileged_counter_timers
    port map (
        cycleCounter_value => cycleCounter_value,
        systemtimer_value => systemtimer_value,
        instructionsRetired_value => instructionsRetired_value,
        address => address_to_unprivileged_counter_timers,
        read_high => read_high_to_unprivileged_counter_timers,
        read_data => read_data_from_unprivileged_counter_timers,
        error => error_from_unprivileged_counter_timers
    );

    systemtimer : entity work.riscv32_systemtimer
    generic map (
        clk_period => clk_period,
        timer_period => 1 us
    ) port map (
        clk => clk,
        reset => rst,
        value => systemtimer_value
    );

    cycleCounter : entity work.riscv32_cycleCounter
    port map (
        clk => clk,
        reset => rst,
        value => cycleCounter_value 
    );
end architecture;
