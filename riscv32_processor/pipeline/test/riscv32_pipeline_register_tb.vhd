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

entity riscv32_pipeline_register_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_pipeline_register_tb is
    signal repeatInstruction : boolean;

    signal instructionFromInstructionDecode : riscv32_instruction_type := riscv32_instructionNop;
    signal execControlWord : riscv32_ExecuteControlWord_type;
    signal writeBackControlWord : riscv32_WriteBackControlWord_type;

    signal instructionInRegEx : riscv32_instruction_type := riscv32_instructionNop;
    signal regExWriteBackControlWord : riscv32_WriteBackControlWord_type;
    signal regExRdAddress : riscv32_registerFileAddress_type := 0;

    signal instructionInExMem : riscv32_instruction_type := riscv32_instructionNop;
    signal exMemWriteBackControlWord : riscv32_WriteBackControlWord_type;
    signal exMemRdAddress : riscv32_registerFileAddress_type := 0;
    signal exMemExecResult : riscv32_data_type := (others => '0');

    signal rs1Address : riscv32_registerFileAddress_type := 0;
    signal rs2Address : riscv32_registerFileAddress_type := 0;
    signal rs1DataFromRegFile : riscv32_data_type := (others => '0');
    signal rs2DataFromRegFile : riscv32_data_type := (others => '0');

    signal rs1DataOut : riscv32_data_type;
    signal rs2DataOut : riscv32_data_type;

begin
    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("rs1 dependend on regExRdAddress causes repeat") then
                instructionFromInstructionDecode <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                instructionInRegEx <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                regExRdAddress <= 12;
                rs1Address <= 12;
                wait for 1 fs;
                check(repeatInstruction);
            elsif run("rs1 being zero does not cause repeat") then
                instructionFromInstructionDecode <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                instructionInRegEx <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                regExRdAddress <= 0;
                rs1Address <= 0;
                wait for 1 fs;
                check(not repeatInstruction);
            elsif run("rs1 dependend on exMemRdAddress causes repeat if instruction is memLoad") then
                instructionFromInstructionDecode <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                instructionInExMem <= construct_itype_instruction(opcode => riscv32_opcode_load, funct3 => riscv32_funct3_lb);
                exMemRdAddress <= 12;
                rs1Address <= 12;
                wait for 1 fs;
                check(repeatInstruction);
            elsif run("rs1 dependend on exMemRdAddress does not cause repeat if instruction is not memLoad") then
                instructionFromInstructionDecode <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                instructionInExMem <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                exMemRdAddress <= 12;
                rs1Address <= 12;
                wait for 1 fs;
                check(not repeatInstruction);
            elsif run("rs1 dependend on rexExRdAddress does not cause repeat if instruction is memStore") then
                instructionFromInstructionDecode <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                instructionInRegEx <= construct_stype_instruction(opcode => riscv32_opcode_store, funct3 => riscv32_funct3_sw);
                regExRdAddress <= 12;
                rs1Address <= 12;
                wait for 1 fs;
                check(not repeatInstruction);
            elsif run("rs2 dependend on regExRdAddress causes repeat") then
                instructionFromInstructionDecode <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                instructionInRegEx <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                regExRdAddress <= 12;
                rs2Address <= 12;
                wait for 1 fs;
                check(repeatInstruction);
            elsif run("rs2 dependend on exMemRdAddress causes repeat if instruction is memLoad") then
                instructionFromInstructionDecode <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                instructionInExMem <= construct_itype_instruction(opcode => riscv32_opcode_load, funct3 => riscv32_funct3_lb);
                exMemRdAddress <= 12;
                rs2Address <= 12;
                wait for 1 fs;
                check(repeatInstruction);
            elsif run("rs2 dependend on rexExRdAddress does not cause repeat if instruction is memStore") then
                instructionFromInstructionDecode <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                instructionInRegEx <= construct_stype_instruction(opcode => riscv32_opcode_store, funct3 => riscv32_funct3_sw);
                regExRdAddress <= 12;
                rs2Address <= 12;
                wait for 1 fs;
                check(not repeatInstruction);
            elsif run("Without any forwarding active, rs1DataOut = rs1DataFromRegFile") then
                regExRdAddress <= 1;
                exMemRdAddress <= 2;
                rs1Address <= 3;
                rs1DataFromRegFile <= X"01230123";
                wait for 1 fs;
                check_equal(rs1DataOut, rs1DataFromRegFile);
            elsif run("exMemExecResult is forwarded to rs1DataOut when applicable") then
                instructionInExMem <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                exMemRdAddress <= 12;
                rs1Address <= 12;
                exMemExecResult <= X"abcdabcd";
                rs1DataFromRegFile <= X"01230123";
                wait for 1 fs;
                check_equal(rs1DataOut, exMemExecResult);
            elsif run("exMemExecResult is not forwarded tot rs1DataOut when exMemOp is store") then
                instructionInExMem <= construct_stype_instruction(opcode => riscv32_opcode_store, funct3 => riscv32_funct3_sw);
                exMemRdAddress <= 12;
                rs1Address <= 12;
                exMemExecResult <= X"abcdabcd";
                rs1DataFromRegFile <= X"01230123";
                wait for 1 fs;
                check_equal(rs1DataOut, rs1DataFromRegFile);
            elsif run("exMemExecResult is not forwarded tot rs1DataOut when rs1Address is 0") then
                instructionInExMem <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                exMemRdAddress <= 0;
                rs1Address <= 0;
                exMemExecResult <= X"abcdabcd";
                rs1DataFromRegFile <= X"00000000";
                wait for 1 fs;
                check_equal(rs1DataOut, rs1DataFromRegFile);
            elsif run("Without any forwarding active, rs2DataOut = rs2DataFromRegFile") then
                regExRdAddress <= 1;
                exMemRdAddress <= 2;
                rs2Address <= 3;
                rs2DataFromRegFile <= X"01230123";
                wait for 1 fs;
                check_equal(rs2DataOut, rs2DataFromRegFile);
            end if;
        end loop;
        test_runner_cleanup(runner);
        wait;
    end process;

    pipelineRegister : entity src.riscv32_pipeline_register
    port map (
        repeatInstruction => repeatInstruction,
        execControlWord => execControlWord,
        writeBackControlWord => writeBackControlWord,
        regExWriteBackControlWord => regExWriteBackControlWord,
        exMemWriteBackControlWord => exMemWriteBackControlWord,
        regExRdAddress => regExRdAddress,
        exMemRdAddress => exMemRdAddress,
        exMemExecResult => exMemExecResult,
        rs1Address => rs1Address,
        rs2Address => rs2Address,
        rs1DataFromRegFile => rs1DataFromRegFile,
        rs2DataFromRegFile => rs2DataFromRegFile,
        rs1DataOut => rs1DataOut,
        rs2DataOut => rs2DataOut
    );

    idControlDecode : entity src.riscv32_control
    port map (
        instruction => instructionFromInstructionDecode,
        executeControlWord => execControlWord,
        writeBackControlWord => writeBackControlWord
    );

    regExControlDecode : entity src.riscv32_control
    port map (
        instruction => instructionInRegEx,
        writeBackControlWord => regExWriteBackControlWord
    );

    exMemControlDecode : entity src.riscv32_control
    port map (
        instruction => instructionInExMem,
        writeBackControlWord => exMemWriteBackControlWord
    );

end architecture;
