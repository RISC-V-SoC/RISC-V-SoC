library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.riscv32_pkg.all;

entity riscv32_pipeline_idregRegister_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_pipeline_idregRegister_tb is
    constant clk_period : time := 20 ns;
    signal clk : std_logic := '0';
    -- Control in
    signal stall : boolean := false;
    signal nop : boolean := false;
    -- Pipeline control in
    signal executeControlWordIn : riscv32_ExecuteControlWord_type := riscv32_executeControlWordAllFalse;
    signal memoryControlWordIn : riscv32_MemoryControlWord_type := riscv32_memoryControlWordAllFalse;
    signal writeBackControlWordIn : riscv32_WriteBackControlWord_type := riscv32_writeBackControlWordAllFalse;
    -- Pipeline data
    signal isBubbleIn : boolean := false;
    signal programCounterIn : riscv32_address_type := (others => '0');
    signal rs1AddressIn : riscv32_registerFileAddress_type := 0;
    signal rs2AddressIn : riscv32_registerFileAddress_type := 0;
    signal immidiateIn : riscv32_data_type := (others => '0');
    signal uimmidiateIn : riscv32_data_type := (others => '0');
    signal rdAddressIn : riscv32_registerFileAddress_type := 0;
    -- Pipeline control out
    signal executeControlWordOut : riscv32_ExecuteControlWord_type;
    signal memoryControlWordOut : riscv32_MemoryControlWord_type;
    signal writeBackControlWordOut : riscv32_WriteBackControlWord_type;
    -- Pipeline data
    signal isBubbleOut : boolean;
    signal programCounterOut : riscv32_address_type;
    signal rs1DataOut : riscv32_data_type;
    signal rs1AddressOut : riscv32_registerFileAddress_type;
    signal rs2AddressOut : riscv32_registerFileAddress_type;
    signal immidiateOut : riscv32_data_type;
    signal uimmididateOut : riscv32_data_type;
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
                check(isBubbleOut);
            elsif run("Forwards input on rising edge if stall = nop = false") then
                wait until falling_edge(clk);
                stall <= false;
                nop <= false;
                memoryControlWordIn.memOp <= true;
                wait until falling_edge(clk);
                check(memoryControlWordOut.memOp);
            elsif run("Holds input if stall = true") then
                wait until falling_edge(clk);
                stall <= false;
                nop <= false;
                memoryControlWordIn.memOp <= true;
                wait until falling_edge(clk);
                stall <= true;
                memoryControlWordIn.memOp <= false;
                wait until falling_edge(clk);
                check(memoryControlWordOut.memOp);
            elsif run("Clears control words if nop = true") then
                wait until falling_edge(clk);
                stall <= false;
                nop <= false;
                memoryControlWordIn.memOp <= true;
                wait until falling_edge(clk);
                nop <= true;
                wait until falling_edge(clk);
                check(not memoryControlWordOut.memOp);
            elsif run("Nop during stall must not be ignored") then
                wait until falling_edge(clk);
                stall <= false;
                nop <= false;
                memoryControlWordIn.memOp <= true;
                wait until falling_edge(clk);
                nop <= true;
                stall <= true;
                wait until falling_edge(clk);
                check(not memoryControlWordOut.memOp);
            elsif run("isBubbleOut is false if no nop and no isBubbleIn") then
                wait until falling_edge(clk);
                nop <= false;
                isBubbleIn <= false;
                wait until falling_edge(clk);
                check(not isBubbleOut);
            elsif run("isBubbleOut is true if no stall and isBubbleIn") then
                wait until falling_edge(clk);
                isBubbleIn <= true;
                wait until falling_edge(clk);
                check(isBubbleOut);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 us);
    idregReg : entity src.riscv32_pipeline_idregRegister
    port map (
        clk => clk,
        -- Control in
        stall => stall,
        nop => nop,
        -- Pipeline control in
        executeControlWordIn => executeControlWordIn,
        memoryControlWordIn => memoryControlWordIn,
        writeBackControlWordIn => writeBackControlWordIn,
        -- Pipeline data in
        isBubbleIn => isBubbleIn,
        programCounterIn => programCounterIn,
        rs1AddressIn => rs1AddressIn,
        rs2AddressIn => rs2AddressIn,
        immidiateIn => immidiateIn,
        uimmidiateIn => uimmidiateIn,
        rdAddressIn => rdAddressIn,
        -- Pipeline control out
        executeControlWordOut => executeControlWordOut,
        memoryControlWordOut => memoryControlWordOut,
        writeBackControlWordOut => writeBackControlWordOut,
        -- Pipeline data out
        isBubbleOut => isBubbleOut,
        programCounterOut => programCounterOut,
        rs1AddressOut => rs1AddressOut,
        rs2AddressOut => rs2AddressOut,
        immidiateOut => immidiateOut,
        uimmididateOut => uimmididateOut,
        rdAddressOut => rdAddressOut
    );
end architecture;
