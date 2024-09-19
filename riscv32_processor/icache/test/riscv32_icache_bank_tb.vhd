library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.riscv32_pkg.all;

entity riscv32_icache_bank_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_icache_bank_tb is
    constant clk_period : time := 20 ns;
    constant word_count_log2b : natural := 8;
    constant tag_size : natural := 4;

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';

    signal requestAddress : std_logic_vector(word_count_log2b - 1 downto 0) := (others => '0');
    signal instructionOut : riscv32_instruction_type;
    signal instructionIn : riscv32_instruction_type := riscv32_instructionNop;
    signal tagIn : std_logic_vector(tag_size - 1 downto 0) := (others => '0');
    signal hit : boolean;
    signal doWrite : boolean := false;
begin

    clk <= not clk after (clk_period/2);

    main : process
        variable writeValue : riscv32_data_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Instruction: write then read works") then
                wait until falling_edge(clk);
                requestAddress <= X"05";
                instructionIn <= X"01020304";
                doWrite <= true;
                wait until falling_edge(clk);
                check_equal(instructionOut, instructionIn);
            elsif run("hit is true after write") then
                wait until falling_edge(clk);
                requestAddress <= X"05";
                instructionIn <= X"01020304";
                tagIn <= X"5";
                doWrite <= true;
                wait until falling_edge(clk);
                check_true(hit);
            elsif run("rst resets line") then
                wait until falling_edge(clk);
                requestAddress <= X"05";
                instructionIn <= X"01020304";
                tagIn <= X"5";
                doWrite <= true;
                wait until falling_edge(clk);
                rst <= '1';
                wait until falling_edge(clk);
                check_false(hit);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;
    test_runner_watchdog(runner,  100 ns);

    icache_bank : entity src.riscv32_icache_bank
    generic map (
        word_count_log2b => word_count_log2b,
        tag_size => tag_size
    ) port map (
        clk => clk,
        rst => rst,
        requestAddress => requestAddress,
        instructionOut => instructionOut,
        instructionIn => instructionIn,
        tagIn => tagIn,
        hit => hit,
        doWrite => doWrite
    );

end architecture;
