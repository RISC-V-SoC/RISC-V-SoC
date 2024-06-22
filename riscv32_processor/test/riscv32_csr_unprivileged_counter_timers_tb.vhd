library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.riscv32_pkg.all;

entity riscv32_csr_unprivileged_counter_timers_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_csr_unprivileged_counter_timers_tb is
    signal address : natural range 0 to 31;
    signal read_high : boolean;
    signal read_data : riscv32_data_type;
    signal systemtimer_value : unsigned(63 downto 0);
    signal instructionsRetired_value : unsigned(63 downto 0);
    signal cycleCounter_value : unsigned(63 downto 0);
    signal error : boolean;
begin
    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Address 0 contains cyclecounter") then
                cycleCounter_value <= X"c1a1a1a1b2b2b2c2";
                address <= 0;
                read_high <= false;
                wait for 1 ns;
                check_equal(read_data, std_logic_vector(cycleCounter_value(read_data'range)));
            elsif run("Address 0 high contains cyclecounter high") then
                cycleCounter_value <= X"c1a1a1a1b2b2b2c2";
                address <= 0;
                read_high <= true;
                wait for 1 ns;
                check_equal(read_data, std_logic_vector(cycleCounter_value(63 downto 32)));
            elsif run("Address 1 contains systemtimer") then
                systemtimer_value <= X"123456789abcdef0";
                address <= 1;
                read_high <= false;
                wait for 1 ns;
                check_equal(read_data, std_logic_vector(systemtimer_value(read_data'range)));
            elsif run("Address 2 high contains instructionsRetired high") then
                instructionsRetired_value <= X"123456789abcdef0";
                address <= 2;
                read_high <= true;
                wait for 1 ns;
                check_equal(read_data, std_logic_vector(instructionsRetired_value(63 downto 32)));
            elsif run("Address 31 gives error") then
                address <= 31;
                wait for 1 ns;
                check_true(error);
            elsif run("Address 0 gives no error") then
                address <= 0;
                wait for 1 ns;
                check_false(error);
            end if;
        end loop;
        test_runner_cleanup(runner);
        wait;
    end process;

    unpriviledged_counter_timers : entity src.riscv32_csr_unprivileged_counter_timers
    port map (
        cycleCounter_value => cycleCounter_value,
        systemtimer_value => systemtimer_value,
        instructionsRetired_value => instructionsRetired_value,
        address => address,
        read_high => read_high,
        read_data => read_data,
        error => error
    );
end architecture;
