library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.riscv32_pkg;

entity riscv32_flush_manager_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_flush_manager_tb is
    constant clk_period : time := 20 ns;
    constant clk_frequency : natural := (1 sec)/clk_period;
    constant external_memory_count : natural := 2;

    signal clk : std_logic := '0';
    signal rst : boolean := false;

    signal do_flush : boolean := false;
    signal flush_busy : boolean;

    signal dcache_do_flush : boolean;
    signal dcache_flush_busy : boolean := false;

    signal ext_do_flush : boolean_vector(external_memory_count - 1 downto 0);
    signal ext_flush_busy : boolean_vector(external_memory_count - 1 downto 0) := (others => false);
begin
    clk <= not clk after (clk_period/2);
    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Flusher becomes busy one cycle after do_flush") then
                wait until rising_edge(clk);
                do_flush <= true;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_true(flush_busy);
            elsif run("Test full flush run") then
                wait until rising_edge(clk);
                do_flush <= true;
                wait until rising_edge(clk);
                do_flush <= false;
                wait until rising_edge(clk) and dcache_do_flush;
                for i in 0 to external_memory_count - 1 loop
                    check_false(ext_do_flush(i));
                end loop;
                wait until rising_edge(clk);
                check_true(dcache_do_flush);
                dcache_flush_busy <= true;
                wait until rising_edge(clk);
                wait until rising_edge(clk);
                check_false(dcache_do_flush);
                wait for 5*clk_period;
                dcache_flush_busy <= false;
                for ext in 0 to external_memory_count - 1 loop
                    wait until rising_edge(clk) and ext_do_flush(ext);
                    wait until rising_edge(clk);
                    check_true(ext_do_flush(ext));
                    ext_flush_busy(ext) <= true;
                    wait for 5*clk_period;
                    ext_flush_busy(ext) <= false;
                end loop;
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 us);

    flush_manager : entity src.riscv32_flush_manager
    generic map (
        external_memory_count => external_memory_count
    ) port map (
        clk,
        rst,
        do_flush,
        flush_busy,
        dcache_do_flush,
        dcache_flush_busy,
        ext_do_flush,
        ext_flush_busy
    );
end architecture;
