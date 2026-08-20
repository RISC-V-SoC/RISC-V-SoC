library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg.all;
use src.riscv32_pkg.all;

entity riscv32_fp32_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_fp32_tb is
    signal clk : std_logic := '0';
    constant clk_period : time := 40 ns;
    signal rst : boolean := false;

    signal low_prio_rounding_mode : riscv32_f32_rounding_mode := f32_rounding_rne;
    signal high_prio_rounding_mode : riscv32_f32_rounding_mode := f32_rounding_rne;

    signal inputA : riscv32_data_type;
    signal inputB : riscv32_data_type;
    signal inputC : riscv32_data_type;

    signal do_operation : boolean := false;
    signal operation : riscv32_f32_cmd;
    signal stall : boolean;

    signal output : riscv32_data_type;
    signal err_flags : riscv32_f32_exception_flags;

begin

    clk <= not clk after clk_period / 2;

    main : process
        variable expectedOutput : std_logic_vector(output'range);
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Stall rises before the next rising edge") then
                check(clk = '0');
                do_operation <= true;
                wait until rising_edge(clk);
                check(stall);
            elsif run("No operation, no stall") then
                check(clk = '0');
                do_operation <= false;
                wait until rising_edge(clk);
                check_false(stall);
            elsif run("Convert unsigned 1 to float") then
                inputA <= riscv32_data_type(to_unsigned(1, inputA'length));
                operation <= f32_cmd_utof;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                check_equal(output, riscv32_data_type'(X"3f800000"));
            elsif run("Convert unsigned 2 to float") then
                inputA <= riscv32_data_type(to_unsigned(2, inputA'length));
                operation <= f32_cmd_utof;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                check_equal(output, riscv32_data_type'(X"40000000"));
            elsif run("Convert signed -1 to float") then
                inputA <= riscv32_data_type(to_signed(-1, inputA'length));
                operation <= f32_cmd_itof;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                check_equal(output, riscv32_data_type'(X"bf800000"));
            elsif run("Convert signed 1 to float") then
                inputA <= riscv32_data_type(to_signed(1, inputA'length));
                operation <= f32_cmd_itof;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                check_equal(output, riscv32_data_type'(X"3f800000"));
            elsif run("Converting unsigned 16777217 to float should result in the inexact flag being set") then
                inputA <= riscv32_data_type(to_unsigned(16777217, inputA'length));
                operation <= f32_cmd_utof;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                check(err_flags.inexact);
            elsif run("Converting unsigned 1 to float should result in the inexact flag not being set") then
                inputA <= riscv32_data_type(to_unsigned(1, inputA'length));
                operation <= f32_cmd_utof;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                check(not err_flags.inexact);
            elsif run("Converting unsigned 16777217 to float using rounding mode rup results in 16777218") then
                high_prio_rounding_mode <= f32_rounding_rup;
                inputA <= riscv32_data_type(to_unsigned(16777217, inputA'length));
                operation <= f32_cmd_utof;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                check_equal(output, riscv32_data_type'(X"4b800001"));
            elsif run("Converting signed -16777217 to float using rounding mode rup results in -16777216") then
                high_prio_rounding_mode <= f32_rounding_rup;
                inputA <= riscv32_data_type(to_signed(-16777217, inputA'length));
                operation <= f32_cmd_itof;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                check_equal(output, riscv32_data_type'(X"cb800000"));
            elsif run("The result of converting unsigned 0x8000001 to float is inexact") then
                inputA <= riscv32_data_type(to_unsigned(16#8000001#, inputA'length));
                operation <= f32_cmd_utof;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                check(err_flags.inexact);
            elsif run("Converting signed -16777217 to float using rounding mode rdn results in -16777218") then
                high_prio_rounding_mode <= f32_rounding_rdn;
                inputA <= riscv32_data_type(to_signed(-16777217, inputA'length));
                operation <= f32_cmd_itof;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                check_equal(output, riscv32_data_type'(X"cb800001"));
            elsif run("Converting unsigned 16777217 to float using rounding mode rdn results in 16777216") then
                high_prio_rounding_mode <= f32_rounding_rdn;
                inputA <= riscv32_data_type(to_unsigned(16777217, inputA'length));
                operation <= f32_cmd_itof;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                check_equal(output, riscv32_data_type'(X"4b800000"));
            elsif run("Converting unsigned 33554431 to float using rounding mode rne results in 33554432") then
                high_prio_rounding_mode <= f32_rounding_rne;
                inputA <= riscv32_data_type(to_unsigned(33554431, inputA'length));
                operation <= f32_cmd_itof;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                check_equal(output, riscv32_data_type'(X"4c000000"));
            elsif run("rne does not round up if the round up makes the number odd") then
                high_prio_rounding_mode <= f32_rounding_rne;
                inputA <= riscv32_data_type(to_unsigned(134217736, inputA'length));
                operation <= f32_cmd_itof;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                check_equal(output, riscv32_data_type'(X"4d000000"));
            end if;
        end loop;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 us);

    fp32 : entity src.riscv32_fp32
    port map (
        clk => clk,
        rst => rst,
        low_prio_rounding_mode => low_prio_rounding_mode,
        high_prio_rounding_mode => high_prio_rounding_mode,
        inputA => inputA,
        inputB => inputB,
        inputC => inputC,
        do_operation => do_operation,
        operation => operation,
        stall => stall,
        output => output,
        err_flags => err_flags
    );
end architecture;
