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

entity riscv32_pipeline_branchHelper_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_pipeline_branchHelper_tb is
    signal executeControlWord : riscv32_ExecuteControlWord_type := riscv32_executeControlWordAllFalse;
    signal injectBubble : boolean;

    signal instruction : riscv32_instruction_type := (others => '0');
begin
    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("On opcode BRANCH, bubble is true") then
                instruction <= construct_btype_instruction(opcode => riscv32_opcode_branch);
                wait for 1 ns;
                check(injectBubble);
            elsif run("On jal, bubble is false") then
                instruction <= construct_rtype_instruction(opcode => riscv32_opcode_jal);
                wait for 1 ns;
                check(not injectBubble);
            elsif run("On jalr, bubble is true") then
                instruction <= construct_itype_instruction(opcode => riscv32_opcode_jalr);
                wait for 1 ns;
                check(injectBubble);
            end if;
        end loop;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 5 ns);

    branchHelper : entity src.riscv32_pipeline_branchHelper
    port map (
        executeControlWord => executeControlWord,
        injectBubble => injectBubble
    );

    controlDecode : entity src.riscv32_control
    port map (
        instruction => instruction,
        executeControlWord => executeControlWord
    );
end architecture;
