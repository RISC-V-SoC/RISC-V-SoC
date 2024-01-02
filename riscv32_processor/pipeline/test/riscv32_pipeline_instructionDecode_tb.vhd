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

entity riscv32_pipeline_instructionDecode_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_pipeline_instructionDecode_tb is
    constant clk_period : time := 20 ns;

    signal overrideProgramCounter : boolean;
    signal repeatInstruction : boolean;

    signal instructionFromInstructionFetch : riscv32_instruction_type := riscv32_instructionNop;
    signal programCounter : riscv32_address_type := (others => '1');

    signal newProgramCounter : riscv32_address_type;

    signal nopOutput : boolean;

    signal writeBackControlWord : riscv32_WriteBackControlWord_type;
    signal memoryControlWord : riscv32_MemoryControlWord_type;
    signal executeControlWord : riscv32_ExecuteControlWord_type;
    signal rs1Address : riscv32_registerFileAddress_type;
    signal rs2Address : riscv32_registerFileAddress_type;
    signal immidiate : riscv32_data_type;
    signal rdAddress : riscv32_registerFileAddress_type;

    signal loadHazardDetected : boolean := false;
begin
    main : process
        variable instructionIn : riscv32_instruction_type;
        variable expectedJumpTarget : riscv32_address_type;
        variable inputAddress : riscv32_address_type;
        variable expectedRsData : riscv32_data_type;
        variable expectedRtData : riscv32_data_type;
        variable expectedDestinationReg : riscv32_registerFileAddress_type;
        variable expectedShamt : riscv32_shamt_type;
        variable expectedImmidiate : riscv32_data_type;
        variable expectedRsAddress : riscv32_registerFileAddress_type;
        variable expectedRtAddress : riscv32_registerFileAddress_type;
        variable expectedExecuteControlword : riscv32_ExecuteControlWord_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Jal instruction jumps") then
                programCounter <= X"00100000";
                instructionFromInstructionFetch <= construct_utype_instruction(opcode => riscv32_opcode_jal, rd => 6, imm20 => X"01400");
                wait for 1 ns;
                check(overrideProgramCounter);
                check_equal(newProgramCounter, std_logic_vector'(X"00100014"));
                check_equal(rdAddress, 6);
            elsif run("addi creates correct immidiate, rs1 and rd") then
                instructionFromInstructionFetch <= construct_itype_instruction(opcode => riscv32_opcode_opimm, rs1 =>4, rd => 6, funct3 => riscv32_funct3_add_sub, imm12 => X"fe9");
                wait for 1 ns;
                check(not overrideProgramCounter);
                check_equal(rdAddress, 6);
                check_equal(rs1Address, 4);
                check_equal(immidiate, std_logic_vector'(X"ffffffe9"));
            elsif run("ssli creates correct immidate, rs1 and rd") then
                instructionFromInstructionFetch <= construct_itype_instruction(opcode => riscv32_opcode_opimm, rs1 => 12, rd => 23, funct3 => riscv32_funct3_sll, imm12 => X"005");
                wait for 1 ns;
                check(not overrideProgramCounter);
                check_equal(rdAddress, 23);
                check_equal(rs1Address, 12);
                check_equal(immidiate, std_logic_vector'(X"00000005"));
            elsif run("Lui creates correct immdiate and rd") then
                instructionFromInstructionFetch <= construct_utype_instruction(opcode => riscv32_opcode_lui, rd => 12, imm20 => X"fabc2");
                wait for 1 ns;
                check(not overrideProgramCounter);
                check_equal(rdAddress, 12);
                check_equal(immidiate, std_logic_vector'(X"fabc2000"));
            elsif run("Integer register-register operations creates correct rs1, rs2 and rd") then
                instructionFromInstructionFetch <= construct_rtype_instruction(opcode => riscv32_opcode_op, rs1 => 31, rs2 => 30, rd => 12);
                wait for 1 ns;
                check(not overrideProgramCounter);
                check_equal(rdAddress, 12);
                check_equal(rs1Address, 31);
                check_equal(rs2Address, 30);
            elsif run("Load hazard detected causes repeat") then
                loadHazardDetected <= true;
                wait for 1 ns;
                check(repeatInstruction);
            elsif run("Branch instructions cause correct rs2, rs1 and immidiate") then
                instructionFromInstructionFetch <= construct_btype_instruction(opcode => riscv32_opcode_branch, rs1 => 1, rs2 => 2, funct3 => riscv32_funct3_bne, imm5 => "10100", imm7 => "0000000");
                wait for 1 ns;
                check(not overrideProgramCounter);
                check_equal(rs1Address, 1);
                check_equal(rs2Address, 2);
                check_equal(immidiate, std_logic_vector'(X"00000014"));
            elsif run("LOAD instructions cause correct rs1, rd and immidiate") then
                instructionFromInstructionFetch <= construct_itype_instruction(opcode => riscv32_opcode_load, rs1 =>4, rd => 6, funct3 => riscv32_funct3_lb, imm12 => X"ffc");
                wait for 1 ns;
                check(not overrideProgramCounter);
                check_equal(rdAddress, 6);
                check_equal(rs1Address, 4);
                check_equal(immidiate, std_logic_vector'(X"fffffffc"));
            elsif run("STORE instructions cause correct rs1, rs2 and immidiate") then
                instructionFromInstructionFetch <= construct_btype_instruction(opcode => riscv32_opcode_store, rs1 =>5, rs2 => 7, funct3 => riscv32_funct3_sb, imm7 => "1111111", imm5 => "11100");
                wait for 1 ns;
                check(not overrideProgramCounter);
                check_equal(rs2Address, 7);
                check_equal(rs1Address, 5);
                check_equal(immidiate, std_logic_vector'(X"fffffffc"));
            end if;
        end loop;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 us);

    instructionDecode : entity src.riscv32_pipeline_instructionDecode
    port map (
        overrideProgramCounter => overrideProgramCounter,
        repeatInstruction => repeatInstruction,
        instructionFromInstructionFetch => instructionFromInstructionFetch,
        programCounter => programCounter,
        newProgramCounter => newProgramCounter,
        nopOutput => nopOutput,
        writeBackControlWord => writeBackControlWord,
        memoryControlWord => memoryControlWord,
        executeControlWord => executeControlWord,
        rs1Address => rs1Address,
        rs2Address => rs2Address,
        immidiate => immidiate,
        rdAddress => rdAddress,
        loadHazardDetected => loadHazardDetected
    );
end architecture;
