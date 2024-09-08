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

entity riscv32_pipeline_instructionFetch_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_pipeline_instructionFetch_tb is
    constant clk_period : time := 20 ns;

    signal clk : std_logic := '0';
    signal rst : boolean := false;

    constant startAddress : riscv32_address_type := X"00000014";
    constant interruptBaseAddress : riscv32_address_type := X"00000400";
    signal requestFromBusAddress : riscv32_address_type;
    signal instructionToInstructionDecode : riscv32_instruction_type;
    signal programCounter : riscv32_address_type;
    signal instructionFromBus : riscv32_instruction_type := (others => '1');
    signal overrideProgramCounterFromID : boolean := false;
    signal newProgramCounterFromID : riscv32_instruction_type := (others => '1');
    signal isBubble : boolean;
    signal overrideProgramCounterFromEx : boolean := false;
    signal newProgramCounterFromEx : riscv32_instruction_type := (others => '1');
    signal stall : boolean := false;
    signal injectBubble : boolean := false;
    signal has_fault : boolean := false;
    signal exception_code : riscv32_exception_code_type := 0;
    signal exception_data : riscv32_exception_data_type;

    signal overrideProgramCounterFromInterrupt : boolean := false;
    signal newProgramCounterFromInterrupt : riscv32_instruction_type := (others => '1');
begin
    clk <= not clk after (clk_period/2);

    main : process
        variable expectedAddress : riscv32_address_type;
        variable expectedInstruction : riscv32_instruction_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("On start, the requested address should be the reset address") then
                wait until rising_edge(clk);
                check_equal(startAddress, requestFromBusAddress);
            elsif run("On stall, the requested address should not increase") then
                stall <= true;
                wait for clk_period;
                check_equal(startAddress, requestFromBusAddress);
            elsif run("Without stall, the requested address should increase") then
                expectedAddress := std_logic_vector(unsigned(startAddress) + 4);
                wait for clk_period;
                check_equal(expectedAddress, requestFromBusAddress);
            elsif run("The override address from ID should be respected") then
                expectedAddress := std_logic_vector(unsigned(startAddress) + 40);
                overrideProgramCounterFromID <= true;
                newProgramCounterFromID <= expectedAddress;
                wait for clk_period;
                check_equal(expectedAddress, requestFromBusAddress);
            elsif run("The override address from EX should be respected") then
                expectedAddress := std_logic_vector(unsigned(startAddress) + 40);
                overrideProgramCounterFromEx <= true;
                newProgramCounterFromEx <= expectedAddress;
                wait for clk_period;
                check_equal(expectedAddress, requestFromBusAddress);
            elsif run("The override address from EX should take precedence") then
                expectedAddress := std_logic_vector(unsigned(startAddress) + 40);
                overrideProgramCounterFromEx <= true;
                newProgramCounterFromEx <= expectedAddress;
                overrideProgramCounterFromID <= true;
                newProgramCounterFromID <= std_logic_vector(unsigned(startAddress) + 16);
                wait for clk_period;
                check_equal(expectedAddress, requestFromBusAddress);
            elsif run("On the first rising edge, a nop should be send to ID") then
                wait until rising_edge(clk);
                check_equal(instructionToInstructionDecode, riscv32_instructionNop);
                check(isBubble);
            elsif run("On the second rising edge, the expected instruction and start address should be send to ID") then
                expectedInstruction := construct_itype_instruction(opcode => riscv32_opcode_opimm, rs1 =>4, rd => 6, funct3 => riscv32_funct3_add_sub, imm12 => X"fe9");
                instructionFromBus <= expectedInstruction;
                expectedAddress := std_logic_vector(unsigned(startAddress));
                wait until rising_edge(clk);
                instructionFromBus <= X"00000002";
                wait until rising_edge(clk);
                check_equal(expectedInstruction, instructionToInstructionDecode);
                check_equal(programCounter, expectedAddress);
                check(not isBubble);
            elsif run("InjectBubble freezes the pc") then
                expectedAddress := std_logic_vector(unsigned(startAddress) + 4);
                wait until falling_edge(clk);
                injectBubble <= true;
                wait until falling_edge(clk);
                check_equal(requestFromBusAddress, expectedAddress);
            elsif run("InjectBubble creates a NOP") then
                instructionFromBus <= X"FF00FF00";
                wait until falling_edge(clk);
                injectBubble <= true;
                wait until falling_edge(clk);
                injectBubble <= false;
                wait until falling_edge(clk);
                check_equal(instructionToInstructionDecode, riscv32_instructionNop);
                check(isBubble);
            elsif run("During stall, injectBubble does nothing") then
                instructionFromBus <= X"FF00FF00";
                wait until falling_edge(clk);
                injectBubble <= true;
                stall <= true;
                wait until falling_edge(clk);
                stall <= false;
                wait until falling_edge(clk);
                check_equal(instructionToInstructionDecode, instructionFromBus);
            elsif run("Check jal instruction flow") then
                -- We start at the falling edge of the clock
                check_equal(requestFromBusAddress, startAddress);
                instructionFromBus <= construct_utype_instruction(opcode => riscv32_opcode_jal, rd => 6, imm20 => X"01400");
                wait for clk_period;
                -- IF should detect this is a jump instruction and freeze the pc
                check_equal(requestFromBusAddress, startAddress);
                -- ID stage determines and calculates jump
                check_equal(instructionToInstructionDecode, instructionFromBus);
                check(not isBubble);
                overrideProgramCounterFromID <= true;
                newProgramCounterFromID <= std_logic_vector(unsigned(startAddress) + 40);
                wait for clk_period;
                -- Now IF should jump and forward a single nop
                check_equal(requestFromBusAddress, std_logic_vector(unsigned(startAddress) + 40));
                check_equal(instructionToInstructionDecode, riscv32_instructionNop);
                check(isBubble);
                instructionFromBus <= construct_itype_instruction(opcode => riscv32_opcode_opimm, rs1 => 12, rd => 23, funct3 => riscv32_funct3_sll, imm12 => X"005");
                overrideProgramCounterFromID <= false;
                newProgramCounterFromID <= (others => 'U');
                wait for clk_period;
                -- IF should move forward to the next instruction
                check_equal(requestFromBusAddress, std_logic_vector(unsigned(startAddress) + 44));
                check_equal(instructionToInstructionDecode, instructionFromBus);
            elsif run("Check jalr instruction flow") then
                -- We start at the falling edge of the clock
                check_equal(requestFromBusAddress, startAddress);
                instructionFromBus <= construct_itype_instruction(opcode => riscv32_opcode_jalr, rs1 =>4, rd => 6, funct3 => 0, imm12 => X"fe9");
                wait for clk_period;
                -- IF should detect this is a jump instruction and freeze the pc
                check_equal(requestFromBusAddress, startAddress);
                -- ID stage determines again that this is a jump and will tell IF to bubble
                check_equal(instructionToInstructionDecode, instructionFromBus);
                check(not isBubble);
                injectBubble <= true;
                wait for clk_period;
                -- On a bubble, the PC should remain frozen
                check_equal(requestFromBusAddress, startAddress);
                check_equal(instructionToInstructionDecode, riscv32_instructionNop);
                check(isBubble);
                -- Now EX will determine the jump target
                overrideProgramCounterFromEX <= true;
                newProgramCounterFromEX <= std_logic_vector(unsigned(startAddress) + 40);
                injectBubble <= false;
                wait for clk_period;
                -- Now IF should jump and forward another nop
                check_equal(requestFromBusAddress, std_logic_vector(unsigned(startAddress) + 40));
                check_equal(instructionToInstructionDecode, riscv32_instructionNop);
                check(isBubble);
                instructionFromBus <= construct_itype_instruction(opcode => riscv32_opcode_opimm, rs1 => 12, rd => 23, funct3 => riscv32_funct3_sll, imm12 => X"005");
                overrideProgramCounterFromEX <= false;
                wait for clk_period;
                -- IF should move forward to the next instruction
                check_equal(requestFromBusAddress, std_logic_vector(unsigned(startAddress) + 44));
                check_equal(instructionToInstructionDecode, instructionFromBus);
                check(not isBubble);
            elsif run("Check branch not taken instruction flow") then
                -- We start at the falling edge of the clock
                check_equal(requestFromBusAddress, startAddress);
                instructionFromBus <= construct_btype_instruction(opcode => riscv32_opcode_branch, rs1 => 1, rs2 => 2, funct3 => riscv32_funct3_bne, imm5 => "10100", imm7 => "0000000");
                wait for clk_period;
                -- IF should detect this is a branch instruction and freeze the pc
                check_equal(requestFromBusAddress, startAddress);
                -- ID stage determines again that this is a branch and will tell IF to bubble
                check_equal(instructionToInstructionDecode, instructionFromBus);
                check(not isBubble);
                injectBubble <= true;
                wait for clk_period;
                -- On a bubble, the PC should remain frozen
                check_equal(requestFromBusAddress, startAddress);
                check_equal(instructionToInstructionDecode, riscv32_instructionNop);
                check(isBubble);
                -- Now EX will determine branch not taken
                injectBubble <= false;
                wait for clk_period;
                -- Now IF should move forward like normal
                check_equal(requestFromBusAddress, std_logic_vector(unsigned(startAddress) + 4));
                check_equal(instructionToInstructionDecode, riscv32_instructionNop);
                check(isBubble);
            elsif run("On has_fault, the correct exception data pops out") then
                has_fault <= true;
                exception_code <= riscv32_exception_code_instruction_access_fault;
                wait for clk_period;
                check_true(exception_data.carries_exception);
                check_equal(exception_data.exception_code, riscv32_exception_code_instruction_access_fault);
                check_equal(exception_data.interrupted_pc, startAddress);
                check_false(exception_data.async_interrupt);
            elsif run("No has_fault, no exception") then
                has_fault <= false;
                exception_code <= riscv32_exception_code_instruction_access_fault;
                wait for clk_period;
                check_false(exception_data.carries_exception);
            elsif run("While rst is true, there is no exception") then
                rst <= true;
                has_fault <= true;
                wait for clk_period;
                check_false(exception_data.carries_exception);
            elsif run("PC does not update on fault") then
                has_fault <= true;
                exception_code <= riscv32_exception_code_instruction_access_fault;
                wait for clk_period;
                check_equal(requestFromBusAddress, startAddress);
            elsif run("Exception data only pops out once") then
                has_fault <= true;
                exception_code <= riscv32_exception_code_instruction_access_fault;
                wait for clk_period;
                wait for clk_period;
                check_false(exception_data.carries_exception);
            elsif run("Interrupt remains if fault goes away") then
                has_fault <= true;
                exception_code <= riscv32_exception_code_instruction_access_fault;
                wait for clk_period;
                has_fault <= false;
                wait for clk_period;
                check_false(exception_data.carries_exception);
                check_equal(requestFromBusAddress, startAddress);
            elsif run("Check interrupt recovery sequence") then
                has_fault <= true;
                exception_code <= riscv32_exception_code_instruction_access_fault;
                newProgramCounterFromInterrupt <= interruptBaseAddress;
                wait for 10*clk_period;
                overrideProgramCounterFromInterrupt <= true;
                wait for clk_period;
                overrideProgramCounterFromInterrupt <= false;
                check_equal(requestFromBusAddress, interruptBaseAddress);
                instructionFromBus <= construct_itype_instruction(opcode => riscv32_opcode_opimm, rs1 => 12, rd => 23, funct3 => riscv32_funct3_sll, imm12 => X"005");
                has_fault <= false;
                check_equal(instructionToInstructionDecode, riscv32_instructionNop);
                check(isBubble);
                wait for clk_period;
                check_equal(instructionToInstructionDecode, instructionFromBus);
            elsif run("If interrupted, reset clears the interrupt") then
                has_fault <= true;
                exception_code <= riscv32_exception_code_instruction_access_fault;
                newProgramCounterFromInterrupt <= interruptBaseAddress;
                wait for 10*clk_period;
                rst <= true;
                has_fault <= false;
                wait for clk_period;
                rst <= false;
                wait for clk_period;
                check_equal(requestFromBusAddress, std_logic_vector(unsigned(startAddress) + 4));
            elsif run("On first rising_edge, exception_data.carries_interrup is false") then
                wait until rising_edge(clk);
                check_false(exception_data.carries_exception);
            elsif run("Stall holds the fault back") then
                has_fault <= true;
                exception_code <= riscv32_exception_code_instruction_access_fault;
                stall <= true;
                wait for clk_period;
                check_false(exception_data.carries_exception);
                wait for clk_period;
                stall <= false;
                wait for clk_period;
                check_true(exception_data.carries_exception);
                check_equal(exception_data.exception_code, riscv32_exception_code_instruction_access_fault);
                check_equal(exception_data.interrupted_pc, startAddress);
                check_false(exception_data.async_interrupt);
            elsif run("Stall prevents exceptiondata clock out") then
                has_fault <= true;
                exception_code <= riscv32_exception_code_instruction_access_fault;
                wait for clk_period;
                stall <= true;
                check_true(exception_data.carries_exception);
                check_equal(exception_data.exception_code, riscv32_exception_code_instruction_access_fault);
                check_equal(exception_data.interrupted_pc, startAddress);
                check_false(exception_data.async_interrupt);
                wait for clk_period;
                check_true(exception_data.carries_exception);
                check_equal(exception_data.exception_code, riscv32_exception_code_instruction_access_fault);
                check_equal(exception_data.interrupted_pc, startAddress);
                check_false(exception_data.async_interrupt);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 us);

    instructionFetch : entity src.riscv32_pipeline_instructionFetch
    generic map (
        startAddress => startAddress
    ) port map (
        clk => clk,
        rst => rst,
        requestFromBusAddress => requestFromBusAddress,
        instructionFromBus => instructionFromBus,
        has_fault => has_fault,
        exception_code => exception_code,
        instructionToInstructionDecode => instructionToInstructionDecode,
        programCounter => programCounter,
        exception_data => exception_data,
        overrideProgramCounterFromID => overrideProgramCounterFromID,
        newProgramCounterFromID => newProgramCounterFromID,
        isBubble => isBubble,
        overrideProgramCounterFromEx => overrideProgramCounterFromEx,
        newProgramCounterFromEx => newProgramCounterFromEx,
        overrideProgramCounterFromInterrupt => overrideProgramCounterFromInterrupt,
        newProgramCounterFromInterrupt => newProgramCounterFromInterrupt,
        injectBubble => injectBubble,
        stall => stall
    );

end architecture;
