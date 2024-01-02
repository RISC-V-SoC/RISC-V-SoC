library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.riscv32_pkg.all;

library tb;
use tb.riscv32_instruction_builder_pkg.all;

entity riscv32_pipeline_writeBack_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_pipeline_writeBack_tb is
    constant clk_period : time := 20 ns;

    signal clk : std_logic := '0';

    signal writeBackControlWord : riscv32_WriteBackControlWord_type;

    signal execResult : riscv32_data_type := (others => '0');
    signal memDataRead : riscv32_data_type := (others => '0');
    signal rdAddress : riscv32_registerFileAddress_type := 0;

    signal regWrite : boolean;
    signal regWriteAddress : riscv32_registerFileAddress_type;
    signal regWriteData : riscv32_data_type;

    signal instruction : riscv32_instruction_type := (others => '0');
begin
    clk <= not clk after (clk_period/2);

    main : process
        variable expectedRegWriteAddress : riscv32_registerFileAddress_type;
        variable expectedRegWriteData : riscv32_data_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("opcode OPIMM causes execResult write") then
                instruction <= construct_itype_instruction(opcode => riscv32_opcode_opimm);
                execResult <= X"11223344";
                memDataRead <= X"00112233";
                rdAddress <= 4;
                wait for 1 ns;
                check(regWrite);
                check_equal(regWriteAddress, rdAddress);
                check_equal(regWriteData, execResult);
            elsif run("Opcode LUI causes execResult write") then
                instruction <= construct_stype_instruction(opcode => riscv32_opcode_lui);
                execResult <= X"11223344";
                memDataRead <= X"00112233";
                rdAddress <= 6;
                wait for 1 ns;
                check(regWrite);
                check_equal(regWriteAddress, rdAddress);
                check_equal(regWriteData, execResult);
            elsif run("Opcode AIUPC causes execResult write") then
                instruction <= construct_stype_instruction(opcode => riscv32_opcode_auipc);
                execResult <= X"11223344";
                memDataRead <= X"00112233";
                rdAddress <= 31;
                wait for 1 ns;
                check(regWrite);
                check_equal(regWriteAddress, rdAddress);
                check_equal(regWriteData, execResult);
            elsif run("Opcode OP causes execResult write") then
                instruction <= construct_rtype_instruction(opcode => riscv32_opcode_op);
                execResult <= X"11223344";
                memDataRead <= X"00112233";
                rdAddress <= 31;
                wait for 1 ns;
                check(regWrite);
                check_equal(regWriteAddress, rdAddress);
                check_equal(regWriteData, execResult);
            elsif run("Opcode JAL causes execResult write") then
                instruction <= construct_rtype_instruction(opcode => riscv32_opcode_jal);
                execResult <= X"11223344";
                memDataRead <= X"00112233";
                rdAddress <= 31;
                wait for 1 ns;
                check(regWrite);
                check_equal(regWriteAddress, rdAddress);
                check_equal(regWriteData, execResult);
            elsif run("Opcode JALR causes execResult write") then
                instruction <= construct_itype_instruction(opcode => riscv32_opcode_jalr);
                execResult <= X"11223344";
                memDataRead <= X"00112233";
                rdAddress <= 31;
                wait for 1 ns;
                check(regWrite);
                check_equal(regWriteAddress, rdAddress);
                check_equal(regWriteData, execResult);
            elsif run("Opcode BRANCH does not cause write") then
                instruction <= construct_btype_instruction(opcode => riscv32_opcode_branch);
                execResult <= X"11223344";
                memDataRead <= X"00112233";
                rdAddress <= 31;
                wait for 1 ns;
                check(not regWrite);
            elsif run("Opcode LOAD causes memDataRead write") then
                instruction <= construct_itype_instruction(opcode => riscv32_opcode_load);
                execResult <= X"11223344";
                memDataRead <= X"00112233";
                rdAddress <= 31;
                wait for 1 ns;
                check(regWrite);
                check_equal(regWriteAddress, rdAddress);
                check_equal(regWriteData, memDataRead);
            elsif run("Opcode STORE does not cause write") then
                instruction <= construct_stype_instruction(opcode => riscv32_opcode_store);
                execResult <= X"11223344";
                memDataRead <= X"00112233";
                rdAddress <= 31;
                wait for 1 ns;
                check(not regWrite);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 us);
    writeBack_stage : entity src.riscv32_pipeline_writeBack
    port map (
        writeBackControlWord => writeBackControlWord,
        execResult => execResult,
        memDataRead => memDataRead,
        rdAddress => rdAddress,
        regWrite => regWrite,
        regWriteAddress => regWriteAddress,
        regWriteData => regWriteData
    );

    controlDecode : entity src.riscv32_control
    port map (
        instruction => instruction,
        writeBackControlWord => writeBackControlWord
    );
end architecture;
