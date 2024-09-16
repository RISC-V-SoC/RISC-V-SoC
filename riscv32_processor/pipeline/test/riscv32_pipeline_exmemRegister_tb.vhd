library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.riscv32_pkg.all;

entity riscv32_pipeline_exmemRegister_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_pipeline_exmemRegister_tb is
    constant clk_period : time := 20 ns;
    signal clk : std_logic := '0';
    -- Control in
    signal stall : boolean := false;
    signal rst : boolean := false;
    -- Exception data in
    signal exception_data_in : riscv32_exception_data_type;
    -- Pipeline control in
    signal memoryControlWordIn : riscv32_MemoryControlWord_type := riscv32_memoryControlWordAllFalse;
    signal writeBackControlWordIn : riscv32_WriteBackControlWord_type := riscv32_writeBackControlWordAllFalse;
    -- Pipeline data in
    signal isBubbleIn : boolean := false;
    signal execResultIn : riscv32_data_type := (others => '0');
    signal rs1DataIn : riscv32_data_type := (others => '0');
    signal rs2DataIn : riscv32_data_type := (others => '0');
    signal rdAddressIn : riscv32_registerFileAddress_type := 0;
    signal uimmidiateIn : riscv32_data_type := (others => '0');
    -- Exception data out
    signal exception_data_out : riscv32_exception_data_type;
    -- Pipeline control out
    signal memoryControlWordOut : riscv32_MemoryControlWord_type;
    signal writeBackControlWordOut : riscv32_WriteBackControlWord_type;
    -- Pipeline data out
    signal isBubbleOut : boolean;
    signal execResultOut : riscv32_data_type;
    signal rs1DataOut : riscv32_data_type;
    signal rs2DataOut : riscv32_data_type;
    signal rdAddressOut : riscv32_registerFileAddress_type;
    signal uimmidiateOut : riscv32_data_type;
begin
    clk <= not clk after (clk_period/2);

    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Push nop on first rising edge") then
                wait until rising_edge(clk);
                check(memoryControlWordOut = riscv32_memoryControlWordAllFalse);
                check(writeBackControlWordOut = riscv32_writeBackControlWordAllFalse);
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
                exception_data_in.async_interrupt <= false;
                exception_data_in.carries_exception <= true;
                wait until falling_edge(clk);
                check(exception_data_out = exception_data_in);
            elsif run("On incoming exception, nop control data") then
                exception_data_in.carries_exception <= false;
                memoryControlWordIn.memOp <= true;
                wait until falling_edge(clk);
                check(memoryControlWordOut.memOp);
                exception_data_in.carries_exception <= true;
                wait until falling_edge(clk);
                check(memoryControlWordOut = riscv32_memoryControlWordAllFalse);
            elsif run("Once excepted, keeps on forwarding nops") then
                memoryControlWordIn.memOp <= true;
                exception_data_in.carries_exception <= true;
                exception_data_in.exception_code <= riscv32_exception_code_instruction_access_fault;
                wait until falling_edge(clk);
                exception_data_in.carries_exception <= false;
                wait until falling_edge(clk);
                check(memoryControlWordOut = riscv32_memoryControlWordAllFalse);
                check(exception_data_out = riscv32_exception_data_idle);
            elsif run("rst clears exception") then
                memoryControlWordIn.memOp <= true;
                exception_data_in.carries_exception <= true;
                exception_data_in.exception_code <= riscv32_exception_code_instruction_access_fault;
                wait until falling_edge(clk);
                exception_data_in.carries_exception <= false;
                wait until falling_edge(clk);
                rst <= true;
                wait until falling_edge(clk);
                rst <= false;
                wait until falling_edge(clk);
                check(memoryControlWordOut.memOp);
            elsif run("Stall delays exception") then
                exception_data_in.carries_exception <= true;
                exception_data_in.exception_code <= riscv32_exception_code_instruction_access_fault;
                stall <= true;
                wait until falling_edge(clk);
                check_false(exception_data_out.carries_exception);
            elsif run("Stall makes sure exception output is being held") then
                exception_data_in.carries_exception <= true;
                exception_data_in.exception_code <= riscv32_exception_code_instruction_access_fault;
                wait until falling_edge(clk);
                stall <= true;
                wait until falling_edge(clk);
                check_true(exception_data_out.carries_exception);
                stall <= false;
                wait until falling_edge(clk);
                check_false(exception_data_out.carries_exception);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 us);
    exMemReg : entity src.riscv32_pipeline_exmemRegister
    port map (
        clk => clk,
        -- Control in
        stall => stall,
        rst => rst,
        -- Exception data in
        exception_data_in => exception_data_in,
        -- Pipeline control in
        memoryControlWordIn => memoryControlWordIn,
        writeBackControlWordIn => writeBackControlWordIn,
        -- Pipeline data in
        isBubbleIn => isBubbleIn,
        execResultIn => execResultIn,
        rs1DataIn => rs1DataIn,
        rs2DataIn => rs2DataIn,
        rdAddressIn => rdAddressIn,
        uimmidiateIn => uimmidiateIn,
        -- Exception data out
        exception_data_out => exception_data_out,
        -- Pipeline control out
        memoryControlWordOut => memoryControlWordOut,
        writeBackControlWordOut => writeBackControlWordOut,
        -- Pipeline data out
        isBubbleOut => isBubbleOut,
        execResultOut => execResultOut,
        rs1DataOut => rs1DataOut,
        rs2DataOut => rs2DataOut,
        rdAddressOut => rdAddressOut,
        uimmidiateOut => uimmidiateOut
    );
end architecture;
