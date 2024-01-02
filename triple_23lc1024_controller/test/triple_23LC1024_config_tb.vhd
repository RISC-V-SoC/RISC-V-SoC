library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
library tb;
use tb.M23LC1024_pkg.all;
use tb.triple_23lc1024_tb_pkg.all;

entity triple_23LC1024_config_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of triple_23LC1024_config_tb is

    constant clk_period : time := 20 ns;

    constant cs_wait_ticks : natural := 4;
    constant spi_clk_half_period_ticks : natural := 2;
    constant spi_cs_hold_ticks : natural := 3;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal config_done : boolean;

    signal cs_n : std_logic_vector(2 downto 0);
    signal so_sio1 : std_logic;
    signal sio2 : std_logic;
    signal hold_n_sio3 : std_logic;
    signal sck : std_logic;
    signal si_sio0 : std_logic;

    constant actor_mem0 : actor_t := find("M23LC1024.mem0");
    constant actor_mem1 : actor_t := find("M23LC1024.mem1");
    constant actor_mem2 : actor_t := find("M23LC1024.mem2");
    constant actors : actor_vec_t := (
        actor_mem0,
        actor_mem1,
        actor_mem2
    );
begin
    clk <= not clk after (clk_period/2);

    test_runner : process
        variable data                        : OperationMode;

    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Config run when mode is (ByteMode, SpiMode) results in (SeqMode, SqiMode)") then
                set_all_mode(ByteMode, SpiMode, actors, net);
                check_all_mode(ByteMode, SpiMode, actors, net);
                check(not config_done);
                rst <= '0';
                wait until config_done;
                check_all_mode(SeqMode, SqiMode, actors, net);
            elsif run("Config run when mode is (PageMode, SdiMode) results in (SeqMode, SqiMode)") then
                set_all_mode(PageMode, SdiMode, actors, net);
                check_all_mode(PageMode, SdiMode, actors, net);
                check(not config_done);
                rst <= '0';
                wait until config_done;
                check_all_mode(SeqMode, SqiMode, actors, net);
            elsif run("Config run when mode is (SeqMode, SqiMode) results in (SeqMode, SqiMode)") then
                set_all_mode(SeqMode, SqiMode, actors, net);
                check_all_mode(SeqMode, SqiMode, actors, net);
                check(not config_done);
                rst <= '0';
                wait until config_done;
                check_all_mode(SeqMode, SqiMode, actors, net);
            elsif run("Config run repeats after rst cycle") then
                set_all_mode(ByteMode, SpiMode, actors, net);
                check_all_mode(ByteMode, SpiMode, actors, net);
                check(not config_done);
                rst <= '0';
                wait until config_done;
                check_all_mode(SeqMode, SqiMode, actors, net);
                set_all_mode(ByteMode, SpiMode, actors, net);
                rst <= '1';
                wait for clk_period;
                check_all_mode(ByteMode, SpiMode, actors, net);
                rst <= '0';
                wait until config_done;
                check_all_mode(SeqMode, SqiMode, actors, net);
            end if;
        end loop;
        wait for 2*clk_period;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  100 us);

    mem_pcb : entity tb.triple_M23LC1024
    port map (
        cs_n => cs_n,
        so_sio1 => so_sio1,
        sio2 => sio2,
        hold_n_sio3 => hold_n_sio3,
        sck => sck,
        si_sio0 => si_sio0
    );

    config : entity src.triple_23lc1024_config
    generic map (
        cs_wait_ticks => cs_wait_ticks,
        spi_clk_half_period_ticks => spi_clk_half_period_ticks,
        spi_cs_hold_ticks => spi_cs_hold_ticks
    )
    port map (
        clk => clk,
        rst => rst,
        spi_clk => sck,
        spi_sio(0) => si_sio0,
        spi_sio(1) => so_sio1,
        spi_sio(2) => sio2,
        spi_sio(3) => hold_n_sio3,
        spi_cs => cs_n,
        config_done => config_done
    );
end tb;
