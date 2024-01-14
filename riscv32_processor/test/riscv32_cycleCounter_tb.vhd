library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;

entity riscv32_cycleCounter_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_cycleCounter_tb is
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
            if run("Value increases on first rising edge") then
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                check_equal(value, to_unsigned(1, value'length));
            elsif run("Value increases on every rising edge") then
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                check_equal(value, to_unsigned(3, value'length));
            elsif run("rst resets the value") then
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                reset <= true;
                wait until rising_edge(clk);
                reset <= false;
                wait until rising_edge(clk);
                check_equal(value, to_unsigned(0, value'length));
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    cycleCounter : entity src.riscv32_cycleCounter
    port map (
        clk => clk,
        reset => reset,
        value => value
    );
end architecture;
