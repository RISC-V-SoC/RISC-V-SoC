library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;

entity reset_controller_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of reset_controller_tb is
    constant master_count : integer := 3;
    constant slave_count : integer := 5;
    constant clk_period : time := 20 ns;
    signal clk : std_logic := '0';
    signal do_reset : boolean := false;
    signal reset_in_progress : boolean;

    signal master_reset : boolean_vector(master_count - 1 downto 0);
    signal slave_reset : boolean_vector(slave_count - 1 downto 0);

begin
    clk <= not clk after (clk_period/2);
    process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("do_reset turns reset_in_progress true") then
                do_reset <= true;
                wait until falling_edge(clk);
                check_equal(reset_in_progress, true);
            elsif run("Without do_reset, reset_in_progress is false") then
                do_reset <= false;
                wait until falling_edge(clk);
                check_equal(reset_in_progress, false);
            elsif run("After do_reset, master_reset is set to true one by one") then
                do_reset <= true;
                for i in 0 to master_count - 1 loop
                    wait until rising_edge(clk) and master_reset(i);
                    for j in 0 to i loop
                        check_equal(master_reset(j), true);
                    end loop;
                    wait until falling_edge(clk);
                end loop;
            elsif run("After all masters are in reset, the slaves are reset one by one") then
                do_reset <= true;
                for i in 0 to slave_count - 1 loop
                    wait until rising_edge(clk) and slave_reset(i);
                    for j in 0 to slave_count - 1 loop
                        if (j <= i) then
                            check_equal(slave_reset(j), true);
                        else
                            check_equal(slave_reset(j), false);
                        end if;
                    end loop;
                    for j in 0 to master_count - 1 loop
                        check_equal(master_reset(j), true);
                    end loop;
                    wait until falling_edge(clk);
                end loop;
            elsif run("After all slaves are reset, they are unreset in reverse order") then
                do_reset <= true;
                wait until rising_edge(clk) and slave_reset(slave_count - 1);
                for i in slave_count - 1 downto 0 loop
                    wait until rising_edge(clk) and not slave_reset(i);
                    for j in slave_count - 1 downto 0 loop
                        if (j >= i) then
                            check_equal(slave_reset(j), false);
                        else
                            check_equal(slave_reset(j), true);
                        end if;
                    end loop;
                    for j in 0 to master_count - 1 loop
                        check_equal(master_reset(j), true);
                    end loop;
                    wait until falling_edge(clk);
                end loop;
            elsif run("Finally, the masters are unreset in reverse order") then
                do_reset <= true;
                wait until rising_edge(clk) and master_reset(master_count - 1);
                for i in master_count - 1 downto 0 loop
                    wait until rising_edge(clk) and not master_reset(i);
                    for j in master_count - 1 downto 0 loop
                        if (j >= i) then
                            check_equal(master_reset(j), false);
                        else
                            check_equal(master_reset(j), true);
                        end if;
                    end loop;
                    wait until falling_edge(clk);
                end loop;
            elsif run("Can do two resets back to back") then
                do_reset <= true;
                wait until rising_edge(clk) and master_reset(master_count - 1);
                do_reset <= false;
                for i in master_count - 1 downto 0 loop
                    wait until rising_edge(clk) and not master_reset(i);
                    for j in master_count - 1 downto 0 loop
                        if (j >= i) then
                            check_equal(master_reset(j), false);
                        else
                            check_equal(master_reset(j), true);
                        end if;
                    end loop;
                    wait until falling_edge(clk);
                end loop;
                do_reset <= true;
                wait until rising_edge(clk) and master_reset(master_count - 1);
                do_reset <= false;
                for i in master_count - 1 downto 0 loop
                    wait until rising_edge(clk) and not master_reset(i);
                    for j in master_count - 1 downto 0 loop
                        if (j >= i) then
                            check_equal(master_reset(j), false);
                        else
                            check_equal(master_reset(j), true);
                        end if;
                    end loop;
                    wait until falling_edge(clk);
                end loop;
            end if;
        end loop;
        wait until rising_edge(clk) or falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 us);

    reset_controller : entity src.reset_controller
    generic map (
        master_count => master_count,
        slave_count => slave_count
    ) port map (
        clk => clk,
        do_reset => do_reset,
        reset_in_progress => reset_in_progress,
        master_reset => master_reset,
        slave_reset => slave_reset
    );
end architecture;
