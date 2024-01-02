library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;

entity generic_fifo_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of generic_fifo_tb is
    constant clk_period : time := 20 ns;
    signal clk : std_logic := '0';
    signal reset : boolean := false;

    signal empty : boolean;
    signal almost_empty : boolean;
    signal full : boolean;
    signal overflow : boolean;
    signal almost_full : boolean;
    signal underflow : boolean;
    signal count : natural range 0 to 16;

    signal data_in : std_logic_vector(7 downto 0) := (others => '0');
    signal push_data : boolean := false;

    signal data_out : std_logic_vector(7 downto 0);
    signal pop_data : boolean := false;
begin
    clk <= not clk after (clk_period/2);
    process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Check state before the first rising_edge") then
                check(empty);
                check(almost_empty);
                check(not full);
                check(not almost_full);
                check_equal(count, 0);
            elsif run("Push one") then
                check_equal(clk, '0');
                data_in <= X"12";
                push_data <= true;
                wait until rising_edge(clk);
                push_data <= false;
                wait until rising_edge(clk) and not empty;
                check(almost_empty);
                check(not full);
                check(not almost_full);
                check_equal(count, 1);
                check_equal(data_out, std_logic_vector'(X"12"));
            elsif run("Push two") then
                check_equal(clk, '0');
                data_in <= X"12";
                push_data <= true;
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                push_data <= false;
                check(not empty);
                check(not almost_empty);
                check(not full);
                check(not almost_full);
                check_equal(count, 2);
                check_equal(data_out, std_logic_vector'(X"12"));
            elsif run("Fill up entirely") then
                for i in 0 to 15 loop
                    data_in <= X"12";
                    push_data <= true;
                    wait until rising_edge(clk);
                    wait until falling_edge(clk);
                    check(not overflow);
                end loop;
                check(full);
                check(almost_full);
                check_equal(count, 16);
            elsif run("Fill up completely, then pop until empty") then
                for i in 0 to 15 loop
                    data_in <= std_logic_vector(to_unsigned(i, data_in'length));
                    push_data <= true;
                    wait until rising_edge(clk);
                end loop;
                push_data <= false;
                wait until falling_edge(clk);
                for i in 0 to 15 loop
                    pop_data <= true;
                    check_equal(data_out, std_logic_vector(to_unsigned(i, data_in'length)));
                    wait until falling_edge(clk);
                end loop;
                check(almost_empty);
                check(empty);
            elsif run("Check overflow") then
                for i in 0 to 16 loop
                    data_in <= std_logic_vector(to_unsigned(i, data_in'length));
                    push_data <= true;
                    wait until rising_edge(clk);
                    check(i < 16 or almost_full);
                end loop;
                push_data <= false;
                wait until falling_edge(clk);
                check(full);
                check(almost_full);
                check_equal(count, 16);
                check(overflow);
            elsif run("Check underflow") then
                for i in 0 to 15 loop
                    data_in <= std_logic_vector(to_unsigned(i, data_in'length));
                    push_data <= true;
                    wait until rising_edge(clk);
                end loop;
                push_data <= false;
                wait until falling_edge(clk);
                for i in 0 to 16 loop
                    pop_data <= true;
                    if i < 16 then
                        check_equal(data_out, std_logic_vector(to_unsigned(i, data_in'length)));
                    end if;
                    check(i < 16 or almost_empty);
                    wait until falling_edge(clk);
                end loop;
                check(empty);
                check(almost_empty);
                check_equal(count, 0);
                check(underflow);
            elsif run("Reset works") then
                data_in <= X"12";
                push_data <= true;
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                push_data <= false;
                reset <= true;
                wait until falling_edge(clk);
                check_equal(0, count);
                check(empty);
                check(almost_empty);
                check(not full);
                check(not almost_full);
                check(not overflow);
                check(not underflow);
            end if;
        end loop;
        wait until rising_edge(clk) or falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    queue : entity src.generic_fifo
    generic map (
        depth_log2b => 4,
        word_size_log2b => 3
    )
    port map (
        clk => clk,
        reset => reset,
        empty => empty,
        almost_empty => almost_empty,
        underflow => underflow,
        full => full,
        almost_full => almost_full,
        overflow => overflow,
        count => count,
        data_in => data_in,
        push_data => push_data,
        data_out => data_out,
        pop_data => pop_data
    );
end architecture;
