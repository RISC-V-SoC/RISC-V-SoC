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

entity riscv32_pipeline_branchPredictor_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_pipeline_branchPredictor_tb is
    constant clk_period : time := 20 ns;
    signal clk : std_logic := '0';
    signal rst : boolean := false;
    signal stall : boolean := false;

    signal instructionToID : riscv32_instruction_type := riscv32_instructionNop;

    signal currentIDProgramCounter : riscv32_address_type := (others => '0');
    signal executeControlWordFromID : riscv32_ExecuteControlWord_type := riscv32_executeControlWordAllFalse;
    signal branchTargetAddressFromID : riscv32_address_type := (others => '-');
    signal exceptionTypeFromID : riscv32_pipeline_exception_type := exception_none;
    signal IDContainsBubble : boolean := false;

    signal branchIsTakenFromEX : boolean := false;
    signal branchIsNotTakenFromEX : boolean := false;
    signal branchTargetAddressFromEX : riscv32_address_type := (others => '-');
        
    signal stallAwaitingBranchResolution : boolean;
    signal handleMisPrediction : boolean;
    signal takeBranch : boolean;
    signal branchTarget : riscv32_address_type;
begin

    clk <= not clk after clk_period/2;

    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("On a JALR, stallAwaitingBranchResolution is held high until branch is taken") then
                wait until falling_edge(clk);
                instructionToID <= construct_itype_instruction(opcode => riscv32_opcode_jalr);
                wait for 1 fs;
                check_true(stallAwaitingBranchResolution);
                wait until falling_edge(clk);
                instructionToID <= riscv32_instructionNop;
                wait for 5*clk_period;
                check_true(stallAwaitingBranchResolution);
                branchIsTakenFromEX <= true;
                branchTargetAddressFromEX <= std_logic_vector(to_unsigned(128, branchTargetAddressFromEX'length));
                wait for 1 fs;
                check_true(takeBranch);
                check_equal(branchTarget, branchTargetAddressFromEX);
                check_true(stallAwaitingBranchResolution);
                wait for clk_period;
                check_false(takeBranch);
                check_false(stallAwaitingBranchResolution);
            elsif run("Check branch taken misprediction") then
                loop
                    wait until falling_edge(clk);
                    branchTargetAddressFromID <= std_logic_vector(to_unsigned(32, branchTargetAddressFromEX'length));
                    currentIDProgramCounter <= std_logic_vector(to_unsigned(64, branchTargetAddressFromEX'length));
                    instructionToID <= construct_itype_instruction(opcode => riscv32_opcode_branch);
                    wait for 1 fs;
                    if takeBranch then
                        exit;
                    end if;
                    wait until falling_edge(clk);
                    instructionToID <= riscv32_instructionNop;
                    wait for 3*clk_period;
                    branchIsTakenFromEX <= true;
                    wait until falling_edge(clk);
                    branchIsTakenFromEX <= false;
                    wait until falling_edge(clk);
                end loop;
                check_equal(branchTarget, branchTargetAddressFromID);
                wait until falling_edge(clk);
                instructionToID <= riscv32_instructionNop;
                branchTargetAddressFromID <= (others => '0');
                currentIDProgramCounter <= (others => '0');
                wait for 3*clk_period;
                branchIsNotTakenFromEX <= true;
                wait for 1 fs;
                check_false(stallAwaitingBranchResolution);
                check_true(handleMisPrediction);
                check_true(takeBranch);
                check_equal(branchTarget, std_logic_vector(to_unsigned(68, branchTargetAddressFromEX'length)));
                wait until falling_edge(clk);
                branchIsNotTakenFromEX <= false;
                check_false(stallAwaitingBranchResolution);
                check_false(handleMisPrediction);
                check_false(takeBranch);
            elsif run("Check branch not taken misprediction") then
                loop
                    wait until falling_edge(clk);
                    branchTargetAddressFromID <= std_logic_vector(to_unsigned(32, branchTargetAddressFromEX'length));
                    currentIDProgramCounter <= std_logic_vector(to_unsigned(64, branchTargetAddressFromEX'length));
                    instructionToID <= construct_itype_instruction(opcode => riscv32_opcode_branch);
                    wait for 1 fs;
                    if not takeBranch then
                        exit;
                    end if;
                    wait until falling_edge(clk);
                    instructionToID <= riscv32_instructionNop;
                    wait for 3*clk_period;
                    branchIsNotTakenFromEX <= true;
                    wait until falling_edge(clk);
                    branchIsNotTakenFromEX <= false;
                    wait until falling_edge(clk);
                end loop;
                wait until falling_edge(clk);
                instructionToID <= riscv32_instructionNop;
                branchTargetAddressFromID <= (others => '0');
                currentIDProgramCounter <= (others => '0');
                wait for 3*clk_period;
                branchIsTakenFromEX <= true;
                branchTargetAddressFromEX <= std_logic_vector(to_unsigned(32, branchTargetAddressFromEX'length));
                wait for 1 fs;
                check_false(stallAwaitingBranchResolution);
                check_true(handleMisPrediction);
                check_true(takeBranch);
                check_equal(branchTarget, std_logic_vector(to_unsigned(32, branchTargetAddressFromEX'length)));
                wait until falling_edge(clk);
                branchIsNotTakenFromEX <= false;
                check_false(stallAwaitingBranchResolution);
                check_false(handleMisPrediction);
                check_false(takeBranch);
            elsif run("Stall should hold output") then
                loop
                    wait until falling_edge(clk);
                    branchTargetAddressFromID <= std_logic_vector(to_unsigned(32, branchTargetAddressFromEX'length));
                    currentIDProgramCounter <= std_logic_vector(to_unsigned(64, branchTargetAddressFromEX'length));
                    instructionToID <= construct_itype_instruction(opcode => riscv32_opcode_branch);
                    wait for 1 fs;
                    if not takeBranch then
                        exit;
                    end if;
                    wait until falling_edge(clk);
                    instructionToID <= riscv32_instructionNop;
                    wait for 3*clk_period;
                    branchIsNotTakenFromEX <= true;
                    wait until falling_edge(clk);
                    branchIsNotTakenFromEX <= false;
                    wait until falling_edge(clk);
                end loop;
                wait until falling_edge(clk);
                instructionToID <= riscv32_instructionNop;
                branchTargetAddressFromID <= (others => '0');
                currentIDProgramCounter <= (others => '0');
                wait for 3*clk_period;
                branchIsTakenFromEX <= true;
                branchTargetAddressFromEX <= std_logic_vector(to_unsigned(32, branchTargetAddressFromEX'length));
                stall <= true;
                wait for 5*clk_period;
                check_false(handleMisPrediction);
                check_false(takeBranch);
                stall <= false;
                wait for 1 fs;
                check_true(takeBranch);
                check_equal(branchTarget, std_logic_vector(to_unsigned(32, branchTargetAddressFromEX'length)));
                wait for clk_period;
                check_false(handleMisPrediction);
            elsif run("JALR is ignored if the ID input is a bubble") then
                wait until falling_edge(clk);
                instructionToID <= construct_itype_instruction(opcode => riscv32_opcode_jalr);
                IDContainsBubble <= true;
                wait for 1 fs;
                check_false(stallAwaitingBranchResolution);
            elsif run("JALR is ignored if the ID signals an exception") then
                wait until falling_edge(clk);
                instructionToID <= construct_itype_instruction(opcode => riscv32_opcode_jalr);
                exceptionTypeFromID <= exception_sync;
                wait for 1 fs;
                check_false(stallAwaitingBranchResolution);
            elsif run("JALR during a branch wait triggers stallAwaitingBranchResolution") then
                loop
                    wait until falling_edge(clk);
                    branchTargetAddressFromID <= std_logic_vector(to_unsigned(32, branchTargetAddressFromEX'length));
                    currentIDProgramCounter <= std_logic_vector(to_unsigned(64, branchTargetAddressFromEX'length));
                    instructionToID <= construct_itype_instruction(opcode => riscv32_opcode_branch);
                    wait for 1 fs;
                    if not takeBranch then
                        exit;
                    end if;
                    wait until falling_edge(clk);
                    instructionToID <= riscv32_instructionNop;
                    wait for 3*clk_period;
                    branchIsNotTakenFromEX <= true;
                    wait until falling_edge(clk);
                    branchIsNotTakenFromEX <= false;
                    wait until falling_edge(clk);
                end loop;
                wait until falling_edge(clk);
                instructionToID <= riscv32_instructionNop;
                branchTargetAddressFromID <= (others => '0');
                currentIDProgramCounter <= (others => '0');
                wait for 1*clk_period;
                instructionToID <= construct_itype_instruction(opcode => riscv32_opcode_jalr);
                wait for 1 fs;
                check_true(stallAwaitingBranchResolution);
                wait for 1*clk_period;
                instructionToID <= riscv32_instructionNop;
                wait for 1 fs;
                check_true(stallAwaitingBranchResolution);
            elsif run("Test JALR during correct prediction") then
                loop
                    wait until falling_edge(clk);
                    branchTargetAddressFromID <= std_logic_vector(to_unsigned(32, branchTargetAddressFromEX'length));
                    currentIDProgramCounter <= std_logic_vector(to_unsigned(64, branchTargetAddressFromEX'length));
                    instructionToID <= construct_itype_instruction(opcode => riscv32_opcode_branch);
                    wait for 1 fs;
                    if not takeBranch then
                        exit;
                    end if;
                    wait until falling_edge(clk);
                    instructionToID <= riscv32_instructionNop;
                    wait for 3*clk_period;
                    branchIsNotTakenFromEX <= true;
                    wait until falling_edge(clk);
                    branchIsNotTakenFromEX <= false;
                    wait until falling_edge(clk);
                end loop;
                wait until falling_edge(clk);
                instructionToID <= riscv32_instructionNop;
                branchTargetAddressFromID <= (others => '0');
                currentIDProgramCounter <= (others => '0');
                wait for 1*clk_period;
                instructionToID <= construct_itype_instruction(opcode => riscv32_opcode_jalr);
                wait for 1*clk_period;
                instructionToID <= riscv32_instructionNop;
                wait for 1*clk_period;
                branchIsNotTakenFromEX <= true;
                wait until rising_edge(clk);
                branchIsNotTakenFromEX <= false;
                wait until falling_edge(clk);
                check_true(stallAwaitingBranchResolution);
                branchIsTakenFromEX <= true;
                wait for 1 fs;
                check_true(stallAwaitingBranchResolution);
                wait for clk_period;
                check_false(stallAwaitingBranchResolution);
            elsif run("Test JALR during incorrect prediction") then
                loop
                    wait until falling_edge(clk);
                    branchTargetAddressFromID <= std_logic_vector(to_unsigned(32, branchTargetAddressFromEX'length));
                    currentIDProgramCounter <= std_logic_vector(to_unsigned(64, branchTargetAddressFromEX'length));
                    instructionToID <= construct_itype_instruction(opcode => riscv32_opcode_branch);
                    wait for 1 fs;
                    if not takeBranch then
                        exit;
                    end if;
                    wait until falling_edge(clk);
                    instructionToID <= riscv32_instructionNop;
                    wait for 3*clk_period;
                    branchIsNotTakenFromEX <= true;
                    wait until falling_edge(clk);
                    branchIsNotTakenFromEX <= false;
                    wait until falling_edge(clk);
                end loop;
                wait until falling_edge(clk);
                instructionToID <= riscv32_instructionNop;
                branchTargetAddressFromID <= (others => '0');
                currentIDProgramCounter <= (others => '0');
                wait for 1*clk_period;
                instructionToID <= construct_itype_instruction(opcode => riscv32_opcode_jalr);
                wait for 1*clk_period;
                instructionToID <= riscv32_instructionNop;
                wait for 1*clk_period;
                branchIsTakenFromEX <= true;
                wait for 1 fs;
                check_true(handleMisPrediction);
                check_true(stallAwaitingBranchResolution);
                wait until rising_edge(clk);
                branchIsTakenFromEX <= false;
                wait until falling_edge(clk);
                check_false(stallAwaitingBranchResolution);
            elsif run("Test JALR exactly on correct prediction") then
                loop
                    wait until falling_edge(clk);
                    branchTargetAddressFromID <= std_logic_vector(to_unsigned(32, branchTargetAddressFromEX'length));
                    currentIDProgramCounter <= std_logic_vector(to_unsigned(64, branchTargetAddressFromEX'length));
                    instructionToID <= construct_itype_instruction(opcode => riscv32_opcode_branch);
                    wait for 1 fs;
                    if takeBranch then
                        exit;
                    end if;
                    wait until falling_edge(clk);
                    instructionToID <= riscv32_instructionNop;
                    wait for 3*clk_period;
                    branchIsTakenFromEX <= true;
                    wait until falling_edge(clk);
                    branchIsTakenFromEX <= false;
                    wait until falling_edge(clk);
                end loop;
                wait until falling_edge(clk);
                instructionToID <= riscv32_instructionNop;
                branchTargetAddressFromID <= (others => '0');
                currentIDProgramCounter <= (others => '0');
                wait for 3*clk_period;
                branchIsTakenFromEX <= true;
                instructionToID <= construct_itype_instruction(opcode => riscv32_opcode_jalr);
                wait for 1 fs;
                check_true(stallAwaitingBranchResolution);
                wait until rising_edge(clk);
                branchIsTakenFromEX <= false;
                wait until falling_edge(clk);
                instructionToID <= riscv32_instructionNop;
                check_true(stallAwaitingBranchResolution);
                wait for 2*clk_period;
                branchIsTakenFromEX <= true;
                wait for clk_period;
                check_false(stallAwaitingBranchResolution);
            elsif run("Test JALR exactly on incorrect prediction") then
                loop
                    wait until falling_edge(clk);
                    branchTargetAddressFromID <= std_logic_vector(to_unsigned(32, branchTargetAddressFromEX'length));
                    currentIDProgramCounter <= std_logic_vector(to_unsigned(64, branchTargetAddressFromEX'length));
                    instructionToID <= construct_itype_instruction(opcode => riscv32_opcode_branch);
                    wait for 1 fs;
                    if takeBranch then
                        exit;
                    end if;
                    wait until falling_edge(clk);
                    instructionToID <= riscv32_instructionNop;
                    wait for 3*clk_period;
                    branchIsTakenFromEX <= true;
                    wait until falling_edge(clk);
                    branchIsTakenFromEX <= false;
                    wait until falling_edge(clk);
                end loop;
                wait until falling_edge(clk);
                instructionToID <= riscv32_instructionNop;
                branchTargetAddressFromID <= (others => '0');
                currentIDProgramCounter <= (others => '0');
                wait for 3*clk_period;
                branchIsNotTakenFromEX <= true;
                instructionToID <= construct_itype_instruction(opcode => riscv32_opcode_jalr);
                wait for 1 fs;
                check_true(handleMisPrediction);
                check_false(stallAwaitingBranchResolution);
                wait until rising_edge(clk);
                branchIsNotTakenFromEX <= false;
                wait until falling_edge(clk);
                instructionToID <= riscv32_instructionNop;
                wait for 1 fs;
                check_false(stallAwaitingBranchResolution);
            elsif run("Branch during a branch wait triggers stallAwaitingBranchResolution") then
                loop
                    wait until falling_edge(clk);
                    branchTargetAddressFromID <= std_logic_vector(to_unsigned(32, branchTargetAddressFromEX'length));
                    currentIDProgramCounter <= std_logic_vector(to_unsigned(64, branchTargetAddressFromEX'length));
                    instructionToID <= construct_itype_instruction(opcode => riscv32_opcode_branch);
                    wait for 1 fs;
                    if not takeBranch then
                        exit;
                    end if;
                    wait until falling_edge(clk);
                    instructionToID <= riscv32_instructionNop;
                    wait for 3*clk_period;
                    branchIsNotTakenFromEX <= true;
                    wait until falling_edge(clk);
                    branchIsNotTakenFromEX <= false;
                    wait until falling_edge(clk);
                end loop;
                wait until falling_edge(clk);
                instructionToID <= riscv32_instructionNop;
                branchTargetAddressFromID <= (others => '0');
                currentIDProgramCounter <= (others => '0');
                wait for 1*clk_period;
                instructionToID <= construct_itype_instruction(opcode => riscv32_opcode_branch);
                wait for 1 fs;
                check_true(stallAwaitingBranchResolution);
                wait for 1*clk_period;
                instructionToID <= riscv32_instructionNop;
                wait for 1 fs;
                check_true(stallAwaitingBranchResolution);
            end if;
            -- Branch on branch resolution
            -- IF enable input must be changed: Branch resolution while a jump is in IF/ID is now possible
        end loop;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 5 us);

    controlDecode : entity src.riscv32_control
    port map (
        instruction => instructionToID,
        executeControlWord => executeControlWordFromID
    );

    branchPredictor : entity src.riscv32_pipeline_branchPredictor
    port map (
        clk => clk,
        rst => rst,
        stall => stall,

        currentIDProgramCounter => currentIDProgramCounter,
        executeControlWordFromID => executeControlWordFromID,
        branchTargetAddressFromID => branchTargetAddressFromID,
        exceptionTypeFromID => exceptionTypeFromID,
        IDContainsBubble => IDContainsBubble,

        branchIsTakenFromEX => branchIsTakenFromEX,
        branchIsNotTakenFromEX => branchIsNotTakenFromEX,
        branchTargetAddressFromEX => branchTargetAddressFromEX,
        stallAwaitingBranchResolution => stallAwaitingBranchResolution,
        handleMisPrediction => handleMisPrediction,
        takeBranch => takeBranch,
        branchTarget => branchTarget
    );
end architecture;
