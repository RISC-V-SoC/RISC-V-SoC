library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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
    signal inputA : riscv32_data_type := (others => '0');
    signal inputB : riscv32_data_type := (others => '0');

    signal outputWordHigh : boolean := false;
    signal inputASigned : boolean := false;
    signal inputBSigned : boolean := false;

    signal output : riscv32_data_type;

begin

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
                wait for 1 ns;
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
                wait for 1 ns;
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
                wait for 1 ns;
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
                wait for 1 ns;
                check_equal(unsigned(output), to_unsigned(1, output'length));
                outputWordHigh <= true;
                wait for 1 ns;
                check_equal(output, std_logic_vector'(X"ffffffff"));
            end if;
        end loop;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 us);

    multiplier : entity src.riscv32_multiplier
    port map (
        inputA,
        inputB,
        outputWordHigh,
        inputASigned,
        inputBSigned,
        output
    );
end architecture;
