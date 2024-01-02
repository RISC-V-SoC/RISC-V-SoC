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
    signal rst : std_logic := '0';

    constant startAddress : riscv32_address_type := X"00000014";
    signal requestFromBusAddress : riscv32_address_type;
    signal instructionToInstructionDecode : riscv32_instruction_type;
    signal programCounter : riscv32_address_type;
    signal instructionFromBus : riscv32_instruction_type := (others => '1');
    signal overrideProgramCounterFromID : boolean := false;
    signal newProgramCounterFromID : riscv32_instruction_type := (others => '1');
    signal overrideProgramCounterFromEx : boolean := false;
    signal newProgramCounterFromEx : riscv32_instruction_type := (others => '1');
    signal stall : boolean := false;
    signal injectBubble : boolean := false;
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
            elsif run("On the second rising edge, the expected instruction and start address should be send to ID") then
                expectedInstruction := construct_itype_instruction(opcode => riscv32_opcode_opimm, rs1 =>4, rd => 6, funct3 => riscv32_funct3_add_sub, imm12 => X"fe9");
                instructionFromBus <= expectedInstruction;
                expectedAddress := std_logic_vector(unsigned(startAddress));
                wait until rising_edge(clk);
                instructionFromBus <= X"00000002";
                wait until rising_edge(clk);
                check_equal(expectedInstruction, instructionToInstructionDecode);
                check_equal(programCounter, expectedAddress);
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
                overrideProgramCounterFromID <= true;
                newProgramCounterFromID <= std_logic_vector(unsigned(startAddress) + 40);
                wait for clk_period;
                -- Now IF should jump and forward a single nop
                check_equal(requestFromBusAddress, std_logic_vector(unsigned(startAddress) + 40));
                check_equal(instructionToInstructionDecode, riscv32_instructionNop);
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
                injectBubble <= true;
                wait for clk_period;
                -- On a bubble, the PC should remain frozen
                check_equal(requestFromBusAddress, startAddress);
                check_equal(instructionToInstructionDecode, riscv32_instructionNop);
                -- Now EX will determine the jump target
                overrideProgramCounterFromEX <= true;
                newProgramCounterFromEX <= std_logic_vector(unsigned(startAddress) + 40);
                injectBubble <= false;
                wait for clk_period;
                -- Now IF should jump and forward another nop
                check_equal(requestFromBusAddress, std_logic_vector(unsigned(startAddress) + 40));
                check_equal(instructionToInstructionDecode, riscv32_instructionNop);
                instructionFromBus <= construct_itype_instruction(opcode => riscv32_opcode_opimm, rs1 => 12, rd => 23, funct3 => riscv32_funct3_sll, imm12 => X"005");
                overrideProgramCounterFromEX <= false;
                wait for clk_period;
                -- IF should move forward to the next instruction
                check_equal(requestFromBusAddress, std_logic_vector(unsigned(startAddress) + 44));
                check_equal(instructionToInstructionDecode, instructionFromBus);
            elsif run("Check branch not taken instruction flow") then
                -- We start at the falling edge of the clock
                check_equal(requestFromBusAddress, startAddress);
                instructionFromBus <= construct_btype_instruction(opcode => riscv32_opcode_branch, rs1 => 1, rs2 => 2, funct3 => riscv32_funct3_bne, imm5 => "10100", imm7 => "0000000");
                wait for clk_period;
                -- IF should detect this is a branch instruction and freeze the pc
                check_equal(requestFromBusAddress, startAddress);
                -- ID stage determines again that this is a branch and will tell IF to bubble
                check_equal(instructionToInstructionDecode, instructionFromBus);
                injectBubble <= true;
                wait for clk_period;
                -- On a bubble, the PC should remain frozen
                check_equal(requestFromBusAddress, startAddress);
                check_equal(instructionToInstructionDecode, riscv32_instructionNop);
                -- Now EX will determine branch not taken
                injectBubble <= false;
                wait for clk_period;
                -- Now IF should move forward like normal
                check_equal(requestFromBusAddress, std_logic_vector(unsigned(startAddress) + 4));
                check_equal(instructionToInstructionDecode, riscv32_instructionNop);
                instructionFromBus <= construct_itype_instruction(opcode => riscv32_opcode_opimm, rs1 => 12, rd => 23, funct3 => riscv32_funct3_sll, imm12 => X"005");
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
        instructionToInstructionDecode => instructionToInstructionDecode,
        programCounter => programCounter,
        overrideProgramCounterFromID => overrideProgramCounterFromID,
        newProgramCounterFromID => newProgramCounterFromID,
        overrideProgramCounterFromEx => overrideProgramCounterFromEx,
        newProgramCounterFromEx => newProgramCounterFromEx,
        injectBubble => injectBubble,
        stall => stall
    );

end architecture;
