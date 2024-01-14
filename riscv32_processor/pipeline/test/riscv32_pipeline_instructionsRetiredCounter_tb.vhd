library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.riscv32_pkg.all;

entity riscv32_pipeline_instructionsRetiredCounter_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_pipeline_instructionsRetiredCounter_tb is
    constant clk_period : time := 20 ns;
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal stall : boolean := false;
    signal isBubble : boolean := false;
    signal instructionsRetiredCount : unsigned(63 downto 0);
begin
    clk <= not clk after (clk_period/2);
    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("instructionsRetiredCount starts at zero") then
                check_equal(instructionsRetiredCount, 0);
            elsif run("instructionsRetiredCount increments when expected") then
                isBubble <= false;
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                check_equal(instructionsRetiredCount, 2);
            elsif run("instructionsRetiredCount must not increase if there is a bubble") then
                isBubble <= true;
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                check_equal(instructionsRetiredCount, 0);
            elsif run("instructionsRetiredCount must not increase during a stall") then
                isBubble <= false;
                stall <= true;
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                check_equal(instructionsRetiredCount, 0);
            elsif run("instructionsRetiredCount must reset on rst") then
                isBubble <= false;
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                rst <= '1';
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                check_equal(instructionsRetiredCount, 0);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    instructionsRetiredCounter : entity src.riscv32_pipeline_instructionsRetiredCounter
    port map (
        clk => clk,
        rst => rst,
        stall => stall,
        isBubble => isBubble,
        instructionsRetiredCount => instructionsRetiredCount
    );
end architecture;
