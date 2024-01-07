library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;

entity riscv32_systemtimer_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_systemtimer_tb is
    constant clk_period : time := 20 ns;

    signal clk : std_logic := '0';
    signal reset : boolean := false;
    signal value : unsigned(63 downto 0);
begin
    clk <= not clk after clk_period/2;
    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("After 1.5 us, value should be 1") then
                wait for 1.5 us;
                check_equal(value, to_unsigned(1, value'length));
            elsif run("Value starts at zero") then
                check_equal(value, to_unsigned(0, value'length));
            elsif run("After 10.5 us, value should be 10") then
                wait for 10.5 us;
                check_equal(value, to_unsigned(10, value'length));
            elsif run("Resetting value to zero works") then
                wait for 10.5 us;
                reset <= true;
                wait until rising_edge(clk);
                reset <= false;
                wait for 2.5 us;
                check_equal(value, to_unsigned(2, value'length));
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    systemtimer : entity src.riscv32_systemtimer
    generic map (
        clk_period => clk_period,
        timer_period => 1 us
    ) port map (
        clk => clk,
        reset => reset,
        value => value
    );
end architecture;
