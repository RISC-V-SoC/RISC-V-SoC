library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.riscv32_pkg.all;

entity riscv32_pipeline_stageRegister_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_pipeline_stageRegister_tb is
    constant clk_period : time := 20 ns;
    signal clk : std_logic := '0';
    -- Control in
    signal stall : boolean := false;
    signal rst : boolean := false;
    -- Control out
    signal requires_service : boolean;
    -- Exception data in
    signal exception_data_in : riscv32_exception_data_type;
    signal exception_from_stage : riscv32_pipeline_exception_type := exception_none;
    signal exception_from_stage_code : riscv32_exception_code_type := 0;
    signal force_service_request : boolean := false;
    -- Pipeline control in
    signal registerControlWordIn : riscv32_RegisterControlWord_type := riscv32_registerControlWordAllFalse;
    signal executeControlWordIn : riscv32_ExecuteControlWord_type := riscv32_executeControlWordAllFalse;
    signal memoryControlWordIn : riscv32_MemoryControlWord_type := riscv32_memoryControlWordAllFalse;
    signal writeBackControlWordIn : riscv32_WriteBackControlWord_type := riscv32_writeBackControlWordAllFalse;
    -- Pipeline data in
    signal isBubbleIn : boolean := false;
    signal programCounterIn : riscv32_address_type := (others => '0');
    signal rs1AddressIn : riscv32_registerFileAddress_type := 0;
    signal rs2AddressIn : riscv32_registerFileAddress_type := 0;
    signal execResultIn : riscv32_data_type := (others => '0');
    signal rs1DataIn : riscv32_data_type := (others => '0');
    signal rs2DataIn : riscv32_data_type := (others => '0');
    signal immidiateIn : riscv32_data_type := (others => '0');
    signal uimmidiateIn : riscv32_data_type := (others => '0');
    signal memDataReadIn : riscv32_data_type := (others => '0');
    signal rdAddressIn : riscv32_registerFileAddress_type := 0;
    -- Exception data out
    signal exception_data_out : riscv32_exception_data_type;
    -- Pipeline control out
    signal registerControlWordOut : riscv32_RegisterControlWord_type;
    signal executeControlWordOut : riscv32_ExecuteControlWord_type;
    signal memoryControlWordOut : riscv32_MemoryControlWord_type;
    signal writeBackControlWordOut : riscv32_WriteBackControlWord_type;
    -- Pipeline data out
    signal isBubbleOut : boolean;
    signal programCounterOut : riscv32_address_type;
    signal rs1AddressOut : riscv32_registerFileAddress_type;
    signal rs2AddressOut : riscv32_registerFileAddress_type;
    signal execResultOut : riscv32_data_type;
    signal rs1DataOut : riscv32_data_type;
    signal rs2DataOut : riscv32_data_type;
    signal immidiateOut : riscv32_data_type;
    signal uimmidiateOut : riscv32_data_type;
    signal memDataReadOut : riscv32_data_type;
    signal rdAddressOut : riscv32_registerFileAddress_type;
begin
    clk <= not clk after (clk_period/2);

    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Push nop on first rising edge") then
                wait until rising_edge(clk);
                check(executeControlWordOut = riscv32_executeControlWordAllFalse);
                check(memoryControlWordOut = riscv32_memoryControlWordAllFalse);
                check(writeBackControlWordOut = riscv32_writeBackControlWordAllFalse);
                check(registerControlWordOut = riscv32_registerControlWordAllFalse);
                check(isBubbleOut);
            elsif run("Forwards input on rising edge if stall = rst = false") then
                wait until falling_edge(clk);
                stall <= false;
                rst <= false;
                memoryControlWordIn.memOp <= true;
                wait until falling_edge(clk);
                check(memoryControlWordOut.memOp);
            elsif run("Holds input if stall = true") then
                wait until falling_edge(clk);
                stall <= false;
                rst <= false;
                memoryControlWordIn.memOp <= true;
                wait until falling_edge(clk);
                stall <= true;
                memoryControlWordIn.memOp <= false;
                wait until falling_edge(clk);
                check(memoryControlWordOut.memOp);
            elsif run("Clears control words if rst = true") then
                wait until falling_edge(clk);
                stall <= false;
                rst <= false;
                memoryControlWordIn.memOp <= true;
                wait until falling_edge(clk);
                rst <= true;
                wait until falling_edge(clk);
                check(not memoryControlWordOut.memOp);
            elsif run("Nop during stall must not be ignored") then
                wait until falling_edge(clk);
                stall <= false;
                rst <= false;
                memoryControlWordIn.memOp <= true;
                wait until falling_edge(clk);
                rst <= true;
                stall <= true;
                wait until falling_edge(clk);
                check(not memoryControlWordOut.memOp);
            elsif run("isBubbleOut is false if no rst and no isBubbleIn") then
                wait until falling_edge(clk);
                rst <= false;
                isBubbleIn <= false;
                wait until falling_edge(clk);
                check(not isBubbleOut);
            elsif run("isBubbleOut is true if no stall and isBubbleIn") then
                wait until falling_edge(clk);
                isBubbleIn <= true;
                wait until falling_edge(clk);
                check(isBubbleOut);
            elsif run("exception_data_out follows exception_data_in") then
                wait until falling_edge(clk);
                exception_data_in.exception_code <= riscv32_exception_code_instruction_access_fault;
                exception_data_in.interrupted_pc <= (others => '1');
                exception_data_in.exception_type <= exception_sync;
                wait until falling_edge(clk);
                check(exception_data_out = exception_data_in);
            elsif run("On incoming exception, nop control data") then
                exception_data_in.exception_type <= exception_none;
                memoryControlWordIn.memOp <= true;
                wait until falling_edge(clk);
                check(memoryControlWordOut.memOp);
                exception_data_in.exception_type <= exception_sync;
                wait until falling_edge(clk);
                check(memoryControlWordOut = riscv32_memoryControlWordAllFalse);
            elsif run("Once excepted, keeps on forwarding nops") then
                memoryControlWordIn.memOp <= true;
                exception_data_in.exception_type <= exception_sync;
                exception_data_in.exception_code <= riscv32_exception_code_instruction_access_fault;
                wait until falling_edge(clk);
                exception_data_in.exception_type <= exception_none;
                wait until falling_edge(clk);
                check(memoryControlWordOut = riscv32_memoryControlWordAllFalse);
                check(exception_data_out = riscv32_exception_data_idle);
            elsif run("rst clears exception") then
                memoryControlWordIn.memOp <= true;
                exception_data_in.exception_type <= exception_sync;
                exception_data_in.exception_code <= riscv32_exception_code_instruction_access_fault;
                wait until falling_edge(clk);
                exception_data_in.exception_type <= exception_none;
                wait until falling_edge(clk);
                rst <= true;
                wait until falling_edge(clk);
                rst <= false;
                wait until falling_edge(clk);
                check(memoryControlWordOut.memOp);
            elsif run("Stall delays exception") then
                exception_data_in.exception_type <= exception_sync;
                exception_data_in.exception_code <= riscv32_exception_code_instruction_access_fault;
                stall <= true;
                wait until falling_edge(clk);
                check_true(exception_data_out.exception_type = exception_none);
            elsif run("Stall makes sure exception output is being held") then
                exception_data_in.exception_type <= exception_sync;
                exception_data_in.exception_code <= riscv32_exception_code_instruction_access_fault;
                wait until falling_edge(clk);
                stall <= true;
                wait until falling_edge(clk);
                check_true(exception_data_out.exception_type = exception_sync);
                stall <= false;
                wait until falling_edge(clk);
                check_true(exception_data_out.exception_type = exception_none);
            elsif run("Exception from stage is also acknowledged") then
                wait until falling_edge(clk);
                exception_data_in.exception_code <= riscv32_exception_code_instruction_access_fault;
                exception_data_in.interrupted_pc <= (others => '1');
                exception_data_in.exception_type <= exception_sync;
                exception_from_stage <= exception_sync;
                exception_from_stage_code <= riscv32_exception_code_illegal_instruction;
                wait until falling_edge(clk);
                check_equal(exception_data_out.exception_code, riscv32_exception_code_illegal_instruction);
                check_equal(exception_data_out.interrupted_pc, exception_data_in.interrupted_pc);
                check_true(exception_data_out.exception_type = exception_sync);
            elsif run("Exception return from stage is correctly forwarded") then
                wait until falling_edge(clk);
                exception_data_in.exception_code <= riscv32_exception_code_instruction_access_fault;
                exception_data_in.interrupted_pc <= (others => '1');
                exception_data_in.exception_type <= exception_sync;
                exception_from_stage <= exception_return;
                exception_from_stage_code <= riscv32_exception_code_illegal_instruction;
                wait until falling_edge(clk);
                check_equal(exception_data_out.exception_code, riscv32_exception_code_illegal_instruction);
                check_equal(exception_data_out.interrupted_pc, exception_data_in.interrupted_pc);
                check_true(exception_data_out.exception_type = exception_return);
            elsif run("Requires service follows incoming exception") then
                wait until falling_edge(clk);
                exception_data_in.exception_code <= riscv32_exception_code_instruction_access_fault;
                exception_data_in.interrupted_pc <= (others => '1');
                exception_data_in.exception_type <= exception_sync;
                wait until falling_edge(clk);
                check_true(requires_service);
            elsif run("Requires service is false if there is no exception") then
                exception_data_in.exception_code <= riscv32_exception_code_instruction_access_fault;
                exception_data_in.interrupted_pc <= (others => '1');
                exception_data_in.exception_type <= exception_none;
                wait until falling_edge(clk);
                check_false(requires_service);
            elsif run("Requires service follows force_service_request") then
                force_service_request <= true;
                wait until falling_edge(clk);
                check_true(requires_service);
            elsif run("During a bubble, an exception from stage is ignored") then
                wait until falling_edge(clk);
                isBubbleIn <= true;
                exception_from_stage <= exception_sync;
                exception_from_stage_code <= riscv32_exception_code_illegal_instruction;
                wait until falling_edge(clk);
                check_true(exception_data_out.exception_type = exception_none);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 us);
    stageReg : entity src.riscv32_pipeline_stageRegister
    port map (
        clk => clk,
        -- Control in
        stall => stall,
        rst => rst,
        -- Control out
        requires_service => requires_service,
        -- Exception data in
        exception_data_in => exception_data_in,
        exception_from_stage => exception_from_stage,
        exception_from_stage_code => exception_from_stage_code,
        force_service_request => force_service_request,
        -- Pipeline control in
        registerControlWordIn => registerControlWordIn,
        executeControlWordIn => executeControlWordIn,
        memoryControlWordIn => memoryControlWordIn,
        writeBackControlWordIn => writeBackControlWordIn,
        -- Pipeline data in
        isBubbleIn => isBubbleIn,
        programCounterIn => programCounterIn,
        rs1AddressIn => rs1AddressIn,
        rs2AddressIn => rs2AddressIn,
        execResultIn => execResultIn,
        rs1DataIn => rs1DataIn,
        rs2DataIn => rs2DataIn,
        immidiateIn => immidiateIn,
        uimmidiateIn => uimmidiateIn,
        memDataReadIn => memDataReadIn,
        rdAddressIn => rdAddressIn,
        -- Exception data out
        exception_data_out => exception_data_out,
        -- Pipeline control out
        registerControlWordOut => registerControlWordOut,
        executeControlWordOut => executeControlWordOut,
        memoryControlWordOut => memoryControlWordOut,
        writeBackControlWordOut => writeBackControlWordOut,
        -- Pipeline data out
        isBubbleOut => isBubbleOut,
        programCounterOut => programCounterOut,
        rs1AddressOut => rs1AddressOut,
        rs2AddressOut => rs2AddressOut,
        execResultOut => execResultOut,
        rs1DataOut => rs1DataOut,
        rs2DataOut => rs2DataOut,
        immidiateOut => immidiateOut,
        uimmidiateOut => uimmidiateOut,
        memDataReadOut => memDataReadOut,
        rdAddressOut => rdAddressOut
    );
end architecture;
