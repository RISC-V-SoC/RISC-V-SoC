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

entity riscv32_nonrestoring_divider_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_nonrestoring_divider_tb is
    signal clk : std_logic := '0';
    constant clk_period : time := 40 ns;
    signal rst : boolean := false;

    signal dividend : riscv32_data_type := (others => '0');
    signal divisor : riscv32_data_type := (others => '0');

    signal is_signed : boolean := false;
    signal output_rem : boolean := false;

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
            if run("0 divided by 1 is 0 rem 0") then
                dividend <= std_logic_vector(to_signed(0, dividend'length));
                divisor <= std_logic_vector(to_signed(1, dividend'length));
                is_signed <= false;
                output_rem <= false;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := std_logic_vector(to_signed(0, output'length));
                check_equal(output, expectedOutput);
                output_rem <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := std_logic_vector(to_signed(0, output'length));
                check_equal(output, expectedOutput);
            elsif run("-25 divided by 9 is -2 rem -7") then
                dividend <= std_logic_vector(to_signed(-25, dividend'length));
                divisor <= std_logic_vector(to_signed(9, dividend'length));
                is_signed <= true;
                output_rem <= false;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := std_logic_vector(to_signed(-2, output'length));
                check_equal(output, expectedOutput);
                output_rem <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := std_logic_vector(to_signed(-7, output'length));
                check_equal(output, expectedOutput);
            elsif run("33 divided by -6 is -5 rem 3") then
                dividend <= std_logic_vector(to_signed(33, dividend'length));
                divisor <= std_logic_vector(to_signed(-6, dividend'length));
                is_signed <= true;
                output_rem <= false;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := std_logic_vector(to_signed(-5, output'length));
                check_equal(output, expectedOutput);
                output_rem <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := std_logic_vector(to_signed(3, output'length));
                check_equal(output, expectedOutput);
            elsif run("0xfffffffe divided by 2 is 0x7ffffff rem 0") then
                dividend <= X"fffffffe";
                divisor <= std_logic_vector(to_signed(2, dividend'length));
                is_signed <= false;
                output_rem <= false;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := std_logic_vector(to_signed(16#7fffffff#, output'length));
                check_equal(output, expectedOutput);
                output_rem <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := std_logic_vector(to_signed(0, output'length));
                check_equal(output, expectedOutput);
            elsif run("-2 divided by 2 is -1 rem 0") then
                dividend <= std_logic_vector(to_signed(-2, dividend'length));
                divisor <= std_logic_vector(to_signed(2, dividend'length));
                is_signed <= true;
                output_rem <= false;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := std_logic_vector(to_signed(-1, output'length));
                check_equal(output, expectedOutput);
                output_rem <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := std_logic_vector(to_signed(0, output'length));
                check_equal(output, expectedOutput);
            elsif run("-4 divided by -2 is 2 rem 0") then
                dividend <= std_logic_vector(to_signed(-4, dividend'length));
                divisor <= std_logic_vector(to_signed(-2, dividend'length));
                is_signed <= true;
                output_rem <= false;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := std_logic_vector(to_signed(2, output'length));
                check_equal(output, expectedOutput);
                output_rem <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := std_logic_vector(to_signed(0, output'length));
                check_equal(output, expectedOutput);
            elsif run("-8 divided by -2 is 4 rem 0") then
                dividend <= std_logic_vector(to_signed(-8, dividend'length));
                divisor <= std_logic_vector(to_signed(-2, dividend'length));
                is_signed <= true;
                output_rem <= false;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := std_logic_vector(to_signed(4, output'length));
                check_equal(output, expectedOutput);
                output_rem <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := std_logic_vector(to_signed(0, output'length));
                check_equal(output, expectedOutput);
            elsif run("8 divided by 2 is 4 rem 0") then
                dividend <= std_logic_vector(to_signed(8, dividend'length));
                divisor <= std_logic_vector(to_signed(2, dividend'length));
                is_signed <= false;
                output_rem <= false;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := std_logic_vector(to_signed(4, output'length));
                check_equal(output, expectedOutput);
                output_rem <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := std_logic_vector(to_signed(0, output'length));
                check_equal(output, expectedOutput);
            elsif run("0 divided by 0 unsigned is 0xffffffff rem 0") then
                dividend <= std_logic_vector(to_signed(0, dividend'length));
                divisor <= std_logic_vector(to_signed(0, dividend'length));
                is_signed <= false;
                output_rem <= false;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := X"ffffffff";
                check_equal(output, expectedOutput);
                output_rem <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := std_logic_vector(to_signed(0, output'length));
                check_equal(output, expectedOutput);
            elsif run("-2 divided by 0 is -1 rem -2") then
                dividend <= std_logic_vector(to_signed(-2, dividend'length));
                divisor <= std_logic_vector(to_signed(0, dividend'length));
                is_signed <= true;
                output_rem <= false;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := std_logic_vector(to_signed(-1, output'length));
                check_equal(output, expectedOutput);
                output_rem <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := std_logic_vector(to_signed(-2, output'length));
                check_equal(output, expectedOutput);
            elsif run("INT32_MIN divided by -1 is INT32_MIN rem 0") then
                dividend <= X"80000000";
                divisor <= std_logic_vector(to_signed(-1, dividend'length));
                is_signed <= true;
                output_rem <= false;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := X"80000000";
                check_equal(output, expectedOutput);
                output_rem <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := std_logic_vector(to_signed(0, output'length));
                check_equal(output, expectedOutput);
            elsif run("Test reset handling") then
                dividend <= std_logic_vector(to_signed(-2, dividend'length));
                divisor <= std_logic_vector(to_signed(2, dividend'length));
                is_signed <= true;
                output_rem <= false;
                do_operation <= true;
                wait until rising_edge(clk) and stall;
                wait for 4*clk_period;
                rst <= true;
                dividend <= std_logic_vector(to_signed(0, dividend'length));
                divisor <= std_logic_vector(to_signed(1, dividend'length));
                is_signed <= false;
                do_operation <= false;
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                check_false(stall);
                rst <= false;
                do_operation <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := std_logic_vector(to_signed(0, output'length));
                check_equal(output, expectedOutput);
                output_rem <= true;
                wait until rising_edge(clk) and not stall;
                expectedOutput := std_logic_vector(to_signed(0, output'length));
                check_equal(output, expectedOutput);
            end if;
        end loop;
        test_runner_cleanup(runner);
        wait;
    end process;

    --test_runner_watchdog(runner,  1 us);

    nonrestoring_divider : entity src.riscv32_nonrestoring_divider
    port map (
        clk => clk,
        rst => rst,
        dividend => dividend,
        divisor => divisor,
        is_signed => is_signed,
        output_rem => output_rem,
        do_operation => do_operation,
        stall => stall,
        output => output
    );
end architecture;
