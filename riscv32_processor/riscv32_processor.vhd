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
        dCache_word_count_log2b : natural;
        external_memory_count : natural
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

        reset_request : out boolean;

        do_flush : out boolean_vector(external_memory_count - 1 downto 0);
        flush_busy : in boolean_vector(external_memory_count - 1 downto 0) := (others => false);

        machine_level_external_interrupt_pending : in boolean;
        machine_level_timer_interrupt_pending : in boolean
    );
end entity;

architecture behaviourial of riscv32_processor is
    constant csr_mapping_array : riscv32_csr_mapping_array := (
        (address_low => 16#C00#, mapping_size => 16#C0#),
        (address_low => 16#F00#, mapping_size => 16#80#),
        (address_low => 16#300#, mapping_size => 16#11#),
        (address_low => 16#340#, mapping_size => 16#C#)
    );

    signal pipelineStall : boolean;

    signal pipeline_requests_stall : boolean;

    signal instructionAddress : riscv32_address_type;
    signal instructionFetchEnabled : boolean;
    signal instruction : riscv32_instruction_type;
    signal dataAddress : riscv32_address_type;
    signal dataByteMask : riscv32_byte_mask_type;
    signal dataRead : boolean;
    signal dataWrite : boolean;
    signal dataToBus : riscv32_data_type;
    signal dataFromBus : riscv32_data_type;

    signal controllerStall : boolean;

    signal instructionFetchHasFault : boolean;
    signal instructionFetchExceptionCode : riscv32_exception_code_type;
    signal instructionFetchFaultData : bus_fault_type;
    signal instructionStall : boolean;

    signal memoryHasFault : boolean;
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
    signal csr_to_pipeline : riscv32_from_csr_type;

    signal cycleCounter_value : unsigned(63 downto 0);
    signal systemtimer_value : unsigned(63 downto 0);
    signal instructionsRetired_value : unsigned(63 downto 0);

    signal demux2user_readonly : riscv32_csr_mst2slv_type;
    signal demux2machine_readonly : riscv32_csr_mst2slv_type;
    signal demux2machine_trap_setup : riscv32_csr_mst2slv_type;
    signal demux2machine_trap_handling : riscv32_csr_mst2slv_type;

    signal user_readonly2demux : riscv32_csr_slv2mst_type;
    signal machine_readonly2demux : riscv32_csr_slv2mst_type;
    signal machine_trap_setup2demux : riscv32_csr_slv2mst_type;
    signal machine_trap_handling2demux : riscv32_csr_slv2mst_type;

    signal interrupt_vector_base_address : riscv32_address_type;
    signal machine_interrupts_enabled : boolean;
    signal machine_timer_interrupt_enabled : boolean;
    signal machine_external_interrupt_enabled : boolean;
    signal interrupt_trigger : boolean;
    signal interrupt_resolve : boolean;
    signal interrupt_is_async : boolean;
    signal exception_code : riscv32_exception_code_type;
    signal interrupted_pc : riscv32_address_type;
    signal pc_on_interrupt_return : riscv32_address_type;

    signal flush_dcache : boolean;
    signal dcache_flush_in_progress : boolean;

    signal flush_manager_do_flush : boolean;
    signal flush_manager_busy : boolean;

    signal async_exception_pending : boolean;
    signal async_exception_code : riscv32_exception_code_type;
begin
    pipelineStall <= controllerStall or instructionStall or memoryStall or pipeline_requests_stall;
    forbidBusInteraction <= controllerStall;

    pipeline : entity work.riscv32_pipeline
        generic map (
            startAddress => startAddress
        ) port map (
            clk => clk,
            rst => rst,
            stall => pipelineStall,
            instructionAddress => instructionAddress,
            instructionReadEnable => instructionFetchEnabled,
            instruction => instruction,
            if_has_fault => instructionFetchHasFault,
            if_exception_code => instructionFetchExceptionCode,
            dataAddress => dataAddress,
            dataByteMask => dataByteMask,
            dataRead => dataRead,
            dataWrite => dataWrite,
            dataOut => dataToBus,
            dataIn => dataFromBus,
            dataFault => memoryHasFault,
            address_to_regFile => bus_slv_to_regFile_address,
            write_to_regFile => bus_slv_to_regFile_doWrite,
            data_to_regFile => bus_slv_to_regFile_data,
            data_from_regFile => regFile_to_bus_slv_data,
            csr_out => pipeline_to_csr,
            csr_in => csr_to_pipeline,
            interrupt_vector_base_address => interrupt_vector_base_address,
            interrupt_return_address => pc_on_interrupt_return,
            interrupt_trigger => interrupt_trigger,
            interrupt_resolve => interrupt_resolve,
            interrupt_is_async => interrupt_is_async,
            exception_code => exception_code,
            interrupted_pc => interrupted_pc,
            async_exception_pending => async_exception_pending,
            async_exception_code => async_exception_code,
            instructionsRetiredCount => instructionsRetired_value,
            stall_out => pipeline_requests_stall
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
        exception_code => instructionFetchExceptionCode,
        faultData => instructionFetchFaultData,
        requestAddress => instructionAddress,
        readEnabled => instructionFetchEnabled,
        instruction => instruction,
        stall => instructionStall
    );

    mem2bus : entity work.riscv32_memTobus
    generic map (
        range_to_cache => dCache_range,
        cache_word_count_log2b => dCache_word_count_log2b
    ) port map (
        clk => clk,
        rst => rst,
        flush_cache => flush_dcache,
        cache_flush_busy => dcache_flush_in_progress,
        mst2slv => memory2slv,
        slv2mst => slv2memory,
        hasFault => memoryHasFault,
        address => dataAddress,
        byteMask => dataByteMask,
        dataIn => dataToBus,
        doWrite => dataWrite,
        doRead => dataRead,
        stallIn => pipelineStall,
        dataOut => dataFromBus,
        stallOut => memoryStall
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
        mem_faultData => (others => '0'),
        cpu_reset => reset_request,
        cpu_stall => controllerStall,
        flush_cache => flush_manager_do_flush,
        cache_flush_in_progress => flush_manager_busy
    );

    flush_manager : entity work.riscv32_flush_manager
    generic map (
        external_memory_count => external_memory_count
    ) port map (
        clk => clk,
        rst => rst,
        do_flush => flush_manager_do_flush,
        flush_busy => flush_manager_busy,
        dcache_do_flush => flush_dcache,
        dcache_flush_busy => dcache_flush_in_progress,
        ext_do_flush => do_flush,
        ext_flush_busy => flush_busy
    );

    async_exception_handler : entity work.riscv32_async_exception_handler
    port map (
        clk => clk,

        async_exception_pending => async_exception_pending,
        async_exception_code => async_exception_code,

        machine_interrupts_enabled => machine_interrupts_enabled,

        machine_level_external_interrupt_pending => machine_level_external_interrupt_pending,
        machine_level_external_interrupt_enabled => machine_external_interrupt_enabled,

        machine_level_timer_interrupt_pending => machine_level_timer_interrupt_pending,
        machine_level_timer_interrupt_enabled => machine_timer_interrupt_enabled,

        machine_level_software_interrupt_pending => false,
        machine_level_software_interrupt_enabled => false
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

    csr_demux : entity work.riscv32_csr_demux
    generic map (
        mapping_array => csr_mapping_array
    ) port map (
        csr_in => pipeline_to_csr,
        csr_out => csr_to_pipeline,
        stall => pipelineStall,
        demux2slv(0) => demux2user_readonly,
        demux2slv(1) => demux2machine_readonly,
        demux2slv(2) => demux2machine_trap_setup,
        demux2slv(3) => demux2machine_trap_handling,
        slv2demux(0) => user_readonly2demux,
        slv2demux(1) => machine_readonly2demux,
        slv2demux(2) => machine_trap_setup2demux,
        slv2demux(3) => machine_trap_handling2demux
    );

    csr_user_readonly : entity work.riscv32_csr_user_readonly
    port map (
        cycleCounter_value => cycleCounter_value,
        systemtimer_value => systemtimer_value,
        instructionsRetired_value => instructionsRetired_value,
        mst2slv => demux2user_readonly,
        slv2mst => user_readonly2demux
    );

    csr_machine_readonly : entity work.riscv32_csr_machine_readonly
    port map (
        mst2slv => demux2machine_readonly,
        slv2mst => machine_readonly2demux
    );

    csr_machine_trap_setup : entity work.riscv32_csr_machine_trap_setup
    port map (
        clk => clk,
        rst => rst,
        mst2slv => demux2machine_trap_setup,
        slv2mst => machine_trap_setup2demux,
        machine_interrupts_enabled => machine_interrupts_enabled,
        interrupt_trigger => interrupt_trigger,
        interrupt_resolved => interrupt_resolve,
        machine_timer_interrupt_enabled => machine_timer_interrupt_enabled,
        machine_external_interrupt_enabled => machine_external_interrupt_enabled,
        interrupt_base_address => interrupt_vector_base_address
    );

    csr_machine_trap_handling : entity work.riscv32_csr_machine_trap_handling
    port map (
        clk => clk,
        rst => rst,
        mst2slv => demux2machine_trap_handling,
        slv2mst => machine_trap_handling2demux,
        machine_timer_interrupt_pending => machine_level_timer_interrupt_pending,
        machine_external_interrupt_pending => machine_level_external_interrupt_pending,
        interrupt_is_async => interrupt_is_async,
        exception_code => exception_code,
        interrupted_pc => interrupted_pc,
        pc_on_return => pc_on_interrupt_return,
        interrupt_trigger => interrupt_trigger
    );
end architecture;
