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

entity riscv32_multiplier_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_multiplier_tb is
    signal clk : std_logic := '0';
    constant clk_period : time := 40 ns;
    signal rst : boolean := false;

    signal inputA : riscv32_data_type := (others => '0');
    signal inputB : riscv32_data_type := (others => '0');

    signal outputWordHigh : boolean := false;
    signal inputASigned : boolean := false;
    signal inputBSigned : boolean := false;

    signal do_operation : boolean := false;
    signal stall : boolean;

    signal output : riscv32_data_type;

begin

    clk <= not clk after clk_period / 2;

    main : process
        variable expectedOutput : std_logic_vector(output'range);
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Multiply unsigned 1 by unsigned 1") then
                inputA <= std_logic_vector(to_unsigned(1, inputA'length));
                inputB <= std_logic_vector(to_unsigned(1, inputB'length));
                outputWordHigh <= false;
                inputASigned <= false;
                inputBSigned <= false;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                check_equal(unsigned(output), to_unsigned(1, output'length));
                outputWordHigh <= true;
                wait for 1 ns;
                check_equal(unsigned(output), to_unsigned(0, output'length));
            elsif run("Multiply signed -1 by unsigned 1") then
                inputA <= std_logic_vector(to_signed(-1, inputA'length));
                inputB <= std_logic_vector(to_unsigned(1, inputB'length));
                outputWordHigh <= false;
                inputASigned <= true;
                inputBSigned <= false;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                check_equal(signed(output), to_signed(-1, output'length));
                outputWordHigh <= true;
                wait for 1 ns;
                check_equal(signed(output), to_signed(-1, output'length));
            elsif run("Multiply unsigned 0x8ffffffff by unsigned 5") then
                inputA <= std_logic_vector'(X"8fffffff");
                inputB <= std_logic_vector(to_unsigned(5, inputB'length));
                outputWordHigh <= false;
                inputASigned <= false;
                inputBSigned <= false;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                check_equal(output, std_logic_vector'(X"cffffffb"));
                outputWordHigh <= true;
                wait for 1 ns;
                check_equal(signed(output), to_signed(16#2#, output'length));
            elsif run("Multiply unsigned 0xffffffff with signed -1") then
                inputA <= std_logic_vector'(X"ffffffff");
                inputB <= std_logic_vector(to_signed(-1, inputB'length));
                outputWordHigh <= false;
                inputASigned <= false;
                inputBSigned <= true;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                check_equal(unsigned(output), to_unsigned(1, output'length));
                outputWordHigh <= true;
                wait for 1 ns;
                check_equal(output, std_logic_vector'(X"ffffffff"));
            elsif run("New input causes immidiate stall") then
                inputA <= std_logic_vector(to_unsigned(1, inputA'length));
                inputB <= std_logic_vector(to_unsigned(1, inputB'length));
                outputWordHigh <= false;
                inputASigned <= false;
                inputBSigned <= false;
                do_operation <= true;
                wait for 1 ns;
                check_true(stall);
            elsif run("No do_operation means no stall") then
                inputA <= std_logic_vector(to_unsigned(1, inputA'length));
                inputB <= std_logic_vector(to_unsigned(1, inputB'length));
                outputWordHigh <= false;
                inputASigned <= false;
                inputBSigned <= false;
                do_operation <= false;
                wait for 1 ns;
                check_false(stall);
            elsif run("No operation means that the output does not change") then
                inputA <= std_logic_vector(to_unsigned(1, inputA'length));
                inputB <= std_logic_vector(to_unsigned(1, inputB'length));
                outputWordHigh <= false;
                inputASigned <= false;
                inputBSigned <= false;
                do_operation <= false;
                wait for 20 * clk_period;
                check(or_reduce(output) = '0');
            elsif run("Multiply after multiply") then
                inputA <= std_logic_vector(to_unsigned(1, inputA'length));
                inputB <= std_logic_vector(to_unsigned(1, inputB'length));
                outputWordHigh <= false;
                inputASigned <= false;
                inputBSigned <= false;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                inputA <= std_logic_vector(to_unsigned(1, inputA'length));
                inputB <= std_logic_vector(to_unsigned(2, inputB'length));
                wait until rising_edge(clk) and not stall;
                check_equal(unsigned(output), to_unsigned(2, output'length));
            elsif run("Test reset") then
                inputA <= std_logic_vector(to_unsigned(1, inputA'length));
                inputB <= std_logic_vector(to_unsigned(1, inputB'length));
                outputWordHigh <= false;
                inputASigned <= false;
                inputBSigned <= false;
                do_operation <= true;
                wait until rising_edge(clk);
                inputA <= (others => '0');
                inputB <= (others => '0');
                do_operation <= false;
                rst <= true;
                wait until rising_edge(clk);
                rst <= false;
                wait for 20*clk_period;
                check(or_reduce(output) = '0');
            elsif run("Sign change when output high wipes cache") then
                inputA <= std_logic_vector(to_signed(-1, inputA'length));
                inputB <= std_logic_vector(to_unsigned(1, inputB'length));
                outputWordHigh <= false;
                inputASigned <= true;
                inputBSigned <= false;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                inputASigned <= false;
                outputWordHigh <= true;
                wait until rising_edge(clk) and not stall;
                check(or_reduce(output) = '0');
            elsif run("Sign change when output low does not wipe cache") then
                inputA <= std_logic_vector(to_signed(-1, inputA'length));
                inputB <= std_logic_vector(to_unsigned(1, inputB'length));
                outputWordHigh <= false;
                inputASigned <= true;
                inputBSigned <= false;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                inputASigned <= false;
                wait for 1 ns;
                check_false(stall);
            end if;
        end loop;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 us);

    multiplier : entity src.riscv32_multiplier
    port map (
        clk,
        rst,
        inputA,
        inputB,
        outputWordHigh,
        inputASigned,
        inputBSigned,
        do_operation,
        stall,
        output
    );
end architecture;
