library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;

entity configurable_multishot_timer_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of configurable_multishot_timer_tb is
    constant clk_period : time := 20 ns;
    signal clk : std_logic := '0';
    signal reset : boolean := false;
    signal target_value : unsigned(31 downto 0) := to_unsigned(0, 32);

    signal done : boolean;
begin
    clk <= not clk after (clk_period/2);
    process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Counter can count to five") then
                reset <= true;
                target_value <= to_unsigned(5, target_value'length);
                wait until falling_edge(clk);
                reset <= false;
                wait for 5*clk_period;
                check(done);
            elsif run("Counter target target_value does not change if reset is false") then
                reset <= true;
                target_value <= to_unsigned(5, target_value'length);
                wait until falling_edge(clk);
                reset <= false;
                target_value <= to_unsigned(2, target_value'length);
                wait for 5*clk_period;
                check(done);
            elsif run("Done repeats") then
                reset <= true;
                target_value <= to_unsigned(5, target_value'length);
                wait until falling_edge(clk);
                reset <= false;
                wait for 5*clk_period;
                check(done);
                wait for 5*clk_period;
                check(done);
            elsif run("When target target_value > 0, done is only high for one cycle") then
                reset <= true;
                target_value <= to_unsigned(5, target_value'length);
                wait until falling_edge(clk);
                reset <= false;
                wait for 5*clk_period;
                check(done);
                wait for clk_period;
                check(not done);
            elsif run("Reset resets timer") then
                reset <= true;
                target_value <= to_unsigned(5, target_value'length);
                wait until falling_edge(clk);
                reset <= false;
                wait for 2*clk_period;
                reset <= true;
                wait until falling_edge(clk);
                reset <= false;
                wait for 5*clk_period;
                check(done);
            end if;
        end loop;
        wait until rising_edge(clk) or falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    configurable_timer : entity src.configurable_multishot_timer
    port map (
        clk => clk,
        reset => reset,
        done => done,
        target_value => target_value
    );
end architecture;
