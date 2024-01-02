library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.riscv32_pkg.all;

entity riscv32_icache_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_icache_tb is
    constant clk_period : time := 20 ns;
    constant word_count_log2b : natural := 8;

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';

    signal requestAddress : riscv32_address_type := (others => '0');
    signal instructionOut : riscv32_instruction_type;
    signal instructionIn : riscv32_instruction_type := riscv32_instructionNop;
    signal doWrite : boolean := false;
    signal miss : boolean;
begin

    clk <= not clk after (clk_period/2);

    main : process
        variable writeValue : riscv32_data_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Uncached requestAddress causes miss") then
                requestAddress <= X"00100004";
                wait for 1 ns;
                check(miss);
            elsif run("Storing data leads to hit") then
                wait until falling_edge(clk);
                requestAddress <= X"00100004";
                instructionIn <= X"01020304";
                doWrite <= true;
                wait until falling_edge(clk);
                check(not miss);
            elsif run("Not storing incoming data does not lead to hit") then
                wait until falling_edge(clk);
                requestAddress <= X"00100004";
                instructionIn <= X"01020304";
                doWrite <= false;
                wait until falling_edge(clk);
                check(miss);
            elsif run("Cache can hold instruction") then
                wait until falling_edge(clk);
                requestAddress <= X"00100004";
                instructionIn <= X"01020304";
                doWrite <= true;
                wait until falling_edge(clk);
                check_equal(instructionOut, instructionIn);
            elsif run("Cache can hold two instructions") then
                wait until falling_edge(clk);
                requestAddress <= X"00100004";
                instructionIn <= X"01020304";
                doWrite <= true;
                wait until falling_edge(clk);
                requestAddress <= X"00100008";
                instructionIn <= X"F1F2F3F4";
                doWrite <= true;
                wait until falling_edge(clk);
                requestAddress <= X"00100004";
                wait for 1 ns;
                check_equal(instructionOut, std_logic_vector'(X"01020304"));
            elsif run("Cache fails to hold instructions 256 words apart") then
                wait until falling_edge(clk);
                requestAddress <= X"00100000";
                instructionIn <= X"01020304";
                doWrite <= true;
                wait until falling_edge(clk);
                requestAddress <= X"00100400";
                instructionIn <= X"F1F2F3F4";
                doWrite <= true;
                wait until falling_edge(clk);
                requestAddress <= X"00100000";
                wait for 1 ns;
                check(miss);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;
    test_runner_watchdog(runner,  100 ns);

    icache : entity src.riscv32_icache
    generic map (
        word_count_log2b => word_count_log2b,
        tag_size => 8
    ) port map (
        clk => clk,
        rst => rst,
        requestAddress => requestAddress,
        instructionOut => instructionOut,
        instructionIn => instructionIn,
        doWrite => doWrite,
        miss => miss
    );


end architecture;
