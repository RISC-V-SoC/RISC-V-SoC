library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg.all;
use src.riscv32_pkg.all;

library tb;
use tb.riscv32_instruction_builder_pkg.all;

entity riscv32_pipeline_ifidreg_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_pipeline_ifidreg_tb is
    constant clk_period : time := 20 ns;

    signal clk : std_logic := '0';
    signal rst : boolean := false;
    signal stall : boolean := false;
    signal force_bubble : boolean := false;
    signal force_service_request : boolean := false;

    signal enable_instruction_fetch : boolean;

    signal program_counter : riscv32_address_type := (others => '0');
    signal instruction_from_bus : riscv32_instruction_type := (others => '0');
    signal has_fault_from_bus : boolean := false;
    signal exception_code_from_bus : riscv32_exception_code_type := 0;

    signal exception_data_out : riscv32_exception_data_type;
    signal instruction_out : riscv32_instruction_type;
    signal is_bubble : boolean;
begin

    clk <= not clk after (clk_period/2);

    main : process
        variable expected_instruction : riscv32_instruction_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Check defaults") then
                check_true(enable_instruction_fetch);
                check(exception_data_out.exception_type = exception_none);
                check_equal(instruction_out, riscv32_instructionNop);
                check_true(is_bubble);
            elsif run("Pass trough instruction") then
                instruction_from_bus <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(instruction_out, instruction_from_bus);
                check_false(is_bubble);
            elsif run("On reset, the instruction is a NOP") then
                instruction_from_bus <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                rst <= true;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(instruction_out, riscv32_instructionNop);
                check_true(is_bubble);
            elsif run("On force_bubble, the instruction_out is a NOP") then
                instruction_from_bus <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                force_bubble <= true;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(instruction_out, riscv32_instructionNop);
                check_true(is_bubble);
            elsif run("On force bubble, instruction fetch is disabled") then
                instruction_from_bus <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                force_bubble <= true;
                wait for 1 ns;
                check_false(enable_instruction_fetch);
            elsif run("On stall, the output instruction freezes") then
                expected_instruction := construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                instruction_from_bus <= expected_instruction;
                wait until rising_edge(clk);
                stall <= true;
                instruction_from_bus <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_slt);
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(instruction_out, expected_instruction);
                check_false(is_bubble);
            elsif run("On a jump or branch, instruction fetch is disabled") then
                instruction_from_bus <= construct_utype_instruction(opcode => riscv32_opcode_jal);
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_false(enable_instruction_fetch);
            elsif run("After a jump or branch, a nop pops out") then
                instruction_from_bus <= construct_utype_instruction(opcode => riscv32_opcode_jal);
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(instruction_out, riscv32_instructionNop);
            elsif run("On exception, the exception data is passed through") then
                instruction_from_bus <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                has_fault_from_bus <= true;
                exception_code_from_bus <= riscv32_exception_code_instruction_address_misaligned;
                program_counter <= std_logic_vector(to_unsigned(48, program_counter'length));
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check(exception_data_out.exception_type = exception_sync);
                check_equal(exception_data_out.exception_code, riscv32_exception_code_instruction_address_misaligned);
                check_equal(exception_data_out.interrupted_pc, program_counter);
            elsif run("On exception, instruction fetch is disabled") then
                instruction_from_bus <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                has_fault_from_bus <= true;
                exception_code_from_bus <= riscv32_exception_code_instruction_address_misaligned;
                program_counter <= std_logic_vector(to_unsigned(48, program_counter'length));
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_false(enable_instruction_fetch);
            elsif run("After an exception, ifidreg keeps pushing nops") then
                instruction_from_bus <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                has_fault_from_bus <= true;
                exception_code_from_bus <= riscv32_exception_code_instruction_address_misaligned;
                program_counter <= std_logic_vector(to_unsigned(48, program_counter'length));
                wait until rising_edge(clk);
                has_fault_from_bus <= false;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(instruction_out, riscv32_instructionNop);
            elsif run("rst clears the service_required state") then
                instruction_from_bus <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                has_fault_from_bus <= true;
                exception_code_from_bus <= riscv32_exception_code_instruction_address_misaligned;
                program_counter <= std_logic_vector(to_unsigned(48, program_counter'length));
                wait until rising_edge(clk);
                has_fault_from_bus <= false;
                wait until rising_edge(clk);
                rst <= true;
                wait until rising_edge(clk);
                rst <= false;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(instruction_out, instruction_from_bus);
            elsif run("force_service_request forces a service request") then
                instruction_from_bus <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                force_service_request <= true;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(instruction_out, riscv32_instructionNop);
                check_false(enable_instruction_fetch);
            elsif run("A stall after a jump or branch keeps the instruction popping out") then
                instruction_from_bus <= construct_utype_instruction(opcode => riscv32_opcode_jal);
                wait until rising_edge(clk);
                stall <= true;
                wait until falling_edge(clk);
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(instruction_out, instruction_from_bus);
            elsif run("Stall has a higher priority than force bubble") then
                instruction_from_bus <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                wait until rising_edge(clk);
                force_bubble <= true;
                stall <= true;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(instruction_out, instruction_from_bus);
                check_false(is_bubble);
            elsif run("Stall makes the exception data repeat") then
                instruction_from_bus <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                has_fault_from_bus <= true;
                exception_code_from_bus <= riscv32_exception_code_instruction_address_misaligned;
                program_counter <= std_logic_vector(to_unsigned(48, program_counter'length));
                wait until rising_edge(clk);
                has_fault_from_bus <= false;
                stall <= true;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check(exception_data_out.exception_type = exception_sync);
                check_equal(exception_data_out.exception_code, riscv32_exception_code_instruction_address_misaligned);
                check_equal(exception_data_out.interrupted_pc, program_counter);
            elsif run("Stall takes precedence over incoming exception") then
                instruction_from_bus <= construct_rtype_instruction(opcode => riscv32_opcode_op, funct3 => riscv32_funct3_add_sub);
                program_counter <= std_logic_vector(to_unsigned(44, program_counter'length));
                wait until rising_edge(clk);
                stall <= true;
                has_fault_from_bus <= true;
                exception_code_from_bus <= riscv32_exception_code_instruction_address_misaligned;
                program_counter <= std_logic_vector(to_unsigned(48, program_counter'length));
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(exception_data_out.interrupted_pc, std_logic_vector(to_unsigned(44, program_counter'length)));
                check_equal(instruction_out, instruction_from_bus);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 us);

    ifidreg : entity src.riscv32_pipeline_ifidreg
    port map (
        clk => clk,
        rst => rst,
        stall => stall,
        force_bubble => force_bubble,
        force_service_request => force_service_request,
        enable_instruction_fetch => enable_instruction_fetch,
        program_counter => program_counter,
        instruction_from_bus => instruction_from_bus,
        has_fault_from_bus => has_fault_from_bus,
        exception_code_from_bus => exception_code_from_bus,
        exception_data_out => exception_data_out,
        instruction_out => instruction_out,
        is_bubble => is_bubble
    );
end architecture;
