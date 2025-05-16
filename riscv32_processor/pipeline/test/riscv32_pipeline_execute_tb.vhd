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

entity riscv32_pipeline_execute_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_pipeline_execute_tb is
    signal clk : std_logic := '0';
    signal clk_period : time := 20 ns;

    signal rst : boolean := false;

    signal executeControlWord : riscv32_ExecuteControlWord_type := riscv32_executeControlWordAllFalse;

    signal stall_out : boolean;

    signal rs1Data : riscv32_data_type;
    signal rs2Data : riscv32_data_type;
    signal immidiate : riscv32_data_type;
    signal programCounter : riscv32_address_type;

    signal execResult : riscv32_data_type;

    signal overrideProgramCounter : boolean;
    signal branchNotTaken : boolean;
    signal newProgramCounter : riscv32_address_type;

    signal instruction : riscv32_instruction_type := (others => '0');
begin

    clk <= not clk after clk_period / 2;

    main : process
        variable expectedExecResult : riscv32_data_type;
        variable expectedDestinationRegToMem : riscv32_registerFileAddress_type;
        variable expectedRegDataRead : riscv32_data_type;
        variable expectedBranchTarget : riscv32_address_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Test ADDI") then
                instruction <= construct_itype_instruction(opcode => riscv32_opcode_opimm, funct3 => riscv32_funct3_add_sub);
                rs1Data <= X"00000001";
                immidiate <= X"ffffffff";
                wait for 1 ns;
                check(not overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(execResult, std_logic_vector'(X"00000000"));
            elsif run("Test SLTI") then
                instruction <= construct_itype_instruction(opcode => riscv32_opcode_opimm, funct3 => riscv32_funct3_slt);
                rs1Data <= X"ffffffff";
                immidiate <= X"00000002";
                wait for 1 ns;
                check(not overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(execResult, std_logic_vector'(X"00000001"));
            elsif run("Test SLTIU") then
                instruction <= construct_itype_instruction(opcode => riscv32_opcode_opimm, funct3 => riscv32_funct3_sltu);
                rs1Data <= X"ffffffff";
                immidiate <= X"00000002";
                wait for 1 ns;
                check(not overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(execResult, std_logic_vector'(X"00000000"));
            elsif run("Test ANDI") then
                instruction <= construct_itype_instruction(opcode => riscv32_opcode_opimm, funct3 => riscv32_funct3_and);
                rs1Data <= X"33333333";
                immidiate <= X"11111111";
                wait for 1 ns;
                check(not overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(execResult, std_logic_vector'(X"11111111"));
            elsif run("Test ORI") then
                instruction <= construct_itype_instruction(opcode => riscv32_opcode_opimm, funct3 => riscv32_funct3_or);
                rs1Data <= X"a0a0a0a1";
                immidiate <= X"0b0b0b0b";
                wait for 1 ns;
                check(not overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(execResult, std_logic_vector'(X"abababab"));
            elsif run("Test XORI") then
                instruction <= construct_itype_instruction(opcode => riscv32_opcode_opimm, funct3 => riscv32_funct3_xor);
                rs1Data <= X"a0a0a0a1";
                immidiate <= X"0b0b0b0b";
                wait for 1 ns;
                check(not overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(execResult, std_logic_vector'(X"abababaa"));
            elsif run("Test SLLI") then
                instruction <= construct_stype_instruction(opcode => riscv32_opcode_opimm, funct3 => riscv32_funct3_sll);
                rs1Data <= X"0000ffff";
                immidiate <= X"00000002";
                wait for 1 ns;
                check(not overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(execResult, std_logic_vector'(X"0003fffc"));
            elsif run("Test SRLI") then
                instruction <= construct_stype_instruction(opcode => riscv32_opcode_opimm, funct3 => riscv32_funct3_srl_sra, funct7 => riscv32_funct7_srl);
                rs1Data <= X"0000ffff";
                immidiate <= X"00000002";
                wait for 1 ns;
                check(not overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(execResult, std_logic_vector'(X"00003fff"));
            elsif run("Test SRAI") then
                instruction <= construct_stype_instruction(opcode => riscv32_opcode_opimm, funct3 => riscv32_funct3_srl_sra, funct7 => riscv32_funct7_sra);
                rs1Data <= X"ffffffff";
                immidiate <= X"00000001";
                wait for 1 ns;
                check(not overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(execResult, std_logic_vector'(X"ffffffff"));
            elsif run ("Test LUI") then
                instruction <= construct_stype_instruction(opcode => riscv32_opcode_lui);
                immidiate <= X"fafbc000";
                wait for 1 ns;
                check(not overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(execResult, immidiate);
            elsif run ("Test AIUPC") then
                instruction <= construct_stype_instruction(opcode => riscv32_opcode_auipc);
                immidiate <= X"fafbc000";
                programCounter <= X"00000004";
                wait for 1 ns;
                check(not overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(execResult, std_logic_vector(signed(immidiate) + signed(programCounter)));
            elsif run("Test ADD") then
                instruction <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub, funct7 => riscv32_funct7_add);
                rs1Data <= X"00000007";
                rs2Data <= X"00000007";
                wait for 1 ns;
                check(not overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(execResult, std_logic_vector'(X"0000000e"));
            elsif run("Test SUB") then
                instruction <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub, funct7 => riscv32_funct7_sub);
                rs1Data <= X"00000007";
                rs2Data <= X"00000007";
                wait for 1 ns;
                check(not overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(execResult, std_logic_vector'(X"00000000"));
            elsif run("Test LOAD") then
                instruction <= construct_itype_instruction(opcode => riscv32_opcode_load, funct3 => riscv32_funct3_lb);
                rs1Data <= X"00000001";
                immidiate <= X"ffffffff";
                wait for 1 ns;
                check(not overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(execResult, std_logic_vector'(X"00000000"));
            elsif run("Test STORE") then
                instruction <= construct_itype_instruction(opcode => riscv32_opcode_store, funct3 => riscv32_funct3_sw);
                rs1Data <= X"00000001";
                immidiate <= X"ffffffff";
                wait for 1 ns;
                check(not overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(execResult, std_logic_vector'(X"00000000"));
            elsif run("Test JAL") then
                instruction <= construct_utype_instruction(opcode => riscv32_opcode_jal);
                programCounter <= X"00000004";
                wait for 1 ns;
                check(not overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(execResult, std_logic_vector'(X"00000008"));
            elsif run("Test JALR") then
                instruction <= construct_itype_instruction(opcode => riscv32_opcode_jalr);
                programCounter <= X"00000004";
                rs1Data <= X"00001004";
                immidiate <= X"0000000c";
                wait for 1 ns;
                check(overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(execResult, std_logic_vector'(X"00000008"));
                check_equal(newProgramCounter, std_logic_vector'(X"00001010"));
            elsif run("Test BEQ") then
                instruction <= construct_btype_instruction(opcode => riscv32_opcode_branch, funct3 => riscv32_funct3_beq);
                programCounter <= X"00000004";
                rs1Data <= X"00001004";
                rs2Data <= X"00001004";
                immidiate <= X"0000000c";
                wait for 1 ns;
                check(overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(newProgramCounter, std_logic_vector'(X"00000010"));

                rs1Data <= X"00001004";
                rs2Data <= X"00001000";
                wait for 1 ns;
                check(not overrideProgramCounter);
                check(branchNotTaken);
            elsif run("Test BNE") then
                instruction <= construct_btype_instruction(opcode => riscv32_opcode_branch, funct3 => riscv32_funct3_bne);
                programCounter <= X"00000004";
                rs1Data <= X"00001000";
                rs2Data <= X"00001004";
                immidiate <= X"0000000c";
                wait for 1 ns;
                check(overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(newProgramCounter, std_logic_vector'(X"00000010"));

                rs1Data <= X"00001004";
                rs2Data <= X"00001004";
                wait for 1 ns;
                check(not overrideProgramCounter);
                check(branchNotTaken);
            elsif run("Test BLT") then
                instruction <= construct_btype_instruction(opcode => riscv32_opcode_branch, funct3 => riscv32_funct3_blt);
                programCounter <= X"00000004";
                rs1Data <= X"ffffffff";
                rs2Data <= X"00000000";
                immidiate <= X"00000004";
                wait for 1 ns;
                check(overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(newProgramCounter, std_logic_vector'(X"00000008"));

                rs1Data <= X"ffffffff";
                rs2Data <= X"ffffffff";
                wait for 1 ns;
                check(not overrideProgramCounter);
                check(branchNotTaken);
            elsif run("Test BLTU") then
                instruction <= construct_btype_instruction(opcode => riscv32_opcode_branch, funct3 => riscv32_funct3_bltu);
                programCounter <= X"00000004";
                rs1Data <= X"00000000";
                rs2Data <= X"00000001";
                immidiate <= X"fffffffc";
                wait for 1 ns;
                check(overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(newProgramCounter, std_logic_vector'(X"00000000"));

                rs1Data <= X"00000000";
                rs2Data <= X"00000000";
                wait for 1 ns;
                check(not overrideProgramCounter);
                check(branchNotTaken);
            elsif run("Test BGE") then
                instruction <= construct_btype_instruction(opcode => riscv32_opcode_branch, funct3 => riscv32_funct3_bge);
                programCounter <= X"00000004";
                rs1Data <= X"ffffffff";
                rs2Data <= X"fffffffc";
                immidiate <= X"fffffffc";
                wait for 1 ns;
                check(overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(newProgramCounter, std_logic_vector'(X"00000000"));

                rs1Data <= X"ffffffff";
                rs2Data <= X"00000000";
                wait for 1 ns;
                check(not overrideProgramCounter);
                check(branchNotTaken);
            elsif run("Test BGEU") then
                instruction <= construct_btype_instruction(opcode => riscv32_opcode_branch, funct3 => riscv32_funct3_bgeu);
                programCounter <= X"00000004";
                rs1Data <= X"00000000";
                rs2Data <= X"00000000";
                immidiate <= X"fffffffc";
                wait for 1 ns;
                check(overrideProgramCounter);
                check(not branchNotTaken);
                check_equal(newProgramCounter, std_logic_vector'(X"00000000"));

                rs1Data <= X"00000000";
                rs2Data <= X"00000001";
                wait for 1 ns;
                check(not overrideProgramCounter);
                check(branchNotTaken);
            end if;
        end loop;
        wait for 2 ns;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 us);

    executeStage : entity src.riscv32_pipeline_execute
    port map (
        clk => clk,
        rst => rst,
        stall_out => stall_out,
        executeControlWord => executeControlWord,
        rs1Data => rs1Data,
        rs2Data => rs2Data,
        immidiate => immidiate,
        programCounter => programCounter,
        execResult => execResult,
        overrideProgramCounter => overrideProgramCounter,
        newProgramCounter => newProgramCounter,
        branchNotTaken => branchNotTaken
    );

    controlDecode : entity src.riscv32_control
    port map (
        instruction => instruction,
        executeControlWord => executeControlWord
    );

end architecture;
