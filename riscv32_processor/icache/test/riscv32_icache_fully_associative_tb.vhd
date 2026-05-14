library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.riscv32_pkg.all;

entity riscv32_icache_fully_associative_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_icache_fully_associative_tb is
    constant clk_period : time := 20 ns;
    constant line_count_log2b : natural := 2;
    constant bank_count_log2b : natural := line_count_log2b;
    constant line_count : natural := 2**line_count_log2b;

    signal clk : std_logic := '0';
    signal rst : boolean := false;

    signal requestAddress : riscv32_address_type := (others => '0');
    signal instructionOut : riscv32_instruction_type;
    signal instructionIn : riscv32_instruction_type := riscv32_instructionNop;
    signal do_write : boolean := false;
    signal miss : boolean;
begin

    clk <= not clk after (clk_period/2);

    main : process
        variable writeValue : riscv32_data_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Fill the cache up") then
                for i in 0 to line_count - 1 loop
                    requestAddress <= std_logic_vector(to_unsigned(16#00100000# + i*4, 32));
                    instructionIn <= std_logic_vector(to_unsigned(16#01020300# + i*4, 32));
                    do_write <= true;
                    wait until falling_edge(clk);
                end loop;
                do_write <= false;
                for i in 0 to line_count - 1 loop
                    requestAddress <= std_logic_vector(to_unsigned(16#00100000# + i*4, 32));
                    wait for 1 fs;
                    check_equal(instructionOut, std_logic_vector(to_unsigned(16#01020300# + i*4, 32)));
                    check(not miss);
                end loop;
            elsif run("Oldest gets eliminated first") then
                for i in 0 to line_count - 1 loop
                    requestAddress <= std_logic_vector(to_unsigned(16#00100000# + i*4, 32));
                    instructionIn <= std_logic_vector(to_unsigned(16#01020300# + i*4, 32));
                    do_write <= true;
                    wait until falling_edge(clk);
                end loop;
                requestAddress <= std_logic_vector(to_unsigned(16#0010001c#, 32));
                instructionIn <= std_logic_vector(to_unsigned(16#0102031c#, 32));
                do_write <= true;
                wait until falling_edge(clk);
                do_write <= false;
                requestAddress <= std_logic_vector(to_unsigned(16#00100000#, 32));
                wait for 1 fs;
                check(miss);
                for i in 1 to line_count - 1 loop
                    requestAddress <= std_logic_vector(to_unsigned(16#00100000# + i*4, 32));
                    wait for 1 fs;
                    check(not miss);
                    check_equal(instructionOut, std_logic_vector(to_unsigned(16#01020300# + i*4, 32)));
                end loop;
            elsif run("Read changes age") then
                for i in 0 to line_count - 1 loop
                    requestAddress <= std_logic_vector(to_unsigned(16#00100000# + i*4, 32));
                    instructionIn <= std_logic_vector(to_unsigned(16#01020300# + i*4, 32));
                    do_write <= true;
                    wait until falling_edge(clk);
                end loop;
                do_write <= false;
                requestAddress <= std_logic_vector(to_unsigned(16#00100000#, 32));
                wait for 1 fs;
                check(not miss);
                check_equal(instructionOut, std_logic_vector(to_unsigned(16#01020300#, 32)));
                wait until falling_edge(clk);
                requestAddress <= std_logic_vector(to_unsigned(16#0010001c#, 32));
                instructionIn <= std_logic_vector(to_unsigned(16#0102031c#, 32));
                do_write <= true;
                wait until falling_edge(clk);
                do_write <= false;
                requestAddress <= std_logic_vector(to_unsigned(16#00100000#, 32));
                wait for 1 fs;
                check(not miss);
                check_equal(instructionOut, std_logic_vector(to_unsigned(16#01020300#, 32)));
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;
    test_runner_watchdog(runner, 1 us);

    icache : entity src.riscv32_icache
    generic map (
        line_count_log2b => line_count_log2b,
        bank_count_log2b => bank_count_log2b
    ) port map (
        clk => clk,
        rst => rst,
        requestAddress => requestAddress,
        instructionOut => instructionOut,
        instructionIn => instructionIn,
        do_write => do_write,
        miss => miss
    );


end architecture;
