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
use src.bus_pkg.all;
use src.triple_23lc1024_pkg.all;

entity triple_23LC1024_writer_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of triple_23LC1024_writer_tb is
    constant spi_clk_half_period_ticks : natural := 2;
    constant clk_period : time := 20 ns;
    constant cs_wait_time : time := 50 ns;
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal cs_n : std_logic_vector(2 downto 0) := (others => '1');
    signal so_sio1 : std_logic;
    signal sio2 : std_logic;
    signal hold_n_sio3 : std_logic;
    signal sck : std_logic;
    signal si_sio0 : std_logic;

    signal active : boolean;
    signal ready :  boolean := false;
    signal valid : boolean;
    signal address : std_logic_vector(16 downto 0) := (others => '0');
    signal write_data : bus_data_type := (others => '0');
    signal burst : std_logic := '0';
    signal fault : boolean;
    signal faultData : std_logic_vector(bus_fault_type'range);
    signal request_length : positive range 1 to bus_bytes_per_word;

    signal cs_set : std_logic;
    signal cs_state : std_logic;

    signal cs_allowed_all_high : boolean := true;

    signal cs_request_in : cs_request_type := request_none;
    signal cs_request_out : cs_request_type;

begin
    clk <= not clk after (clk_period/2);

    process
        constant actor : actor_t := find("M23LC1024.mem0");
        variable read_data : bus_data_type;
        variable exp_data : bus_data_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Bus data width should be a multiple of 8") then
                -- We send our data packages in multiples of 8 bit, therefore the bus width
                -- has to be at least 8 bit.
                check(bus_data_width_log2b >= 3);
            elsif run("Write 255 to address zero results in 255 at address zero") then
                set_all_mode(SeqMode, SqiMode, actor, net);
                write_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), std_logic_vector(to_unsigned(0, bus_data_type'length)));
                address <= std_logic_vector(to_unsigned(0, address'length));
                write_data <= std_logic_vector(to_unsigned(255, write_data'length));
                rst <= '0';
                ready <= true;
                burst <= '0';
                request_length <= 4;
                wait until rising_edge(clk) and valid;
                ready <= false;
                address <= (others => 'X');
                write_data <= (others => 'X');
                wait until rising_edge(clk);
                check(not valid);
                check(active);
                wait until not active;
                read_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), read_data);
                check_equal(read_data, std_logic_vector(to_unsigned(255, read_data'length)));
            elsif run("Write 0xFFFEFDFC to address zero results in 0xFFFEFDFC at address zero") then
                exp_data := X"FFFEFDFC";
                set_all_mode(SeqMode, SqiMode, actor, net);
                write_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), (others => '0'));
                address <= std_logic_vector(to_unsigned(0, address'length));
                write_data <= exp_data;
                rst <= '0';
                ready <= true;
                burst <= '0';
                request_length <= 4;
                wait until rising_edge(clk) and valid;
                ready <= false;
                address <= (others => 'X');
                write_data <= (others => 'X');
                wait until rising_edge(cs_n(0));
                read_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), read_data);
                check_equal(reorder_nibbles(read_data), exp_data);
            elsif run("Write 255 to address zero and address 4 results in 255 at address zero and address 4") then
                set_all_mode(SeqMode, SqiMode, actor, net);
                write_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), std_logic_vector(to_unsigned(0, bus_data_type'length)));
                write_bus_word(net, actor, std_logic_vector(to_unsigned(4, 17)), std_logic_vector(to_unsigned(0, bus_data_type'length)));
                address <= std_logic_vector(to_unsigned(0, address'length));
                write_data <= std_logic_vector(to_unsigned(255, write_data'length));
                rst <= '0';
                ready <= true;
                burst <= '0';
                check(not active);
                request_length <= 4;
                wait until rising_edge(clk) and valid;
                ready <= true;
                address <= std_logic_vector(to_unsigned(4, address'length));
                write_data <= std_logic_vector(to_unsigned(255, write_data'length));
                wait until rising_edge(clk) and valid;
                ready <= false;
                address <= (others => 'X');
                write_data <= (others => 'X');
                wait until rising_edge(cs_n(0));
                read_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), read_data);
                check_equal(read_data, std_logic_vector(to_unsigned(255, read_data'length)));
                read_bus_word(net, actor, std_logic_vector(to_unsigned(4, 17)), read_data);
                check_equal(read_data, std_logic_vector(to_unsigned(255, read_data'length)));
            elsif run("Burst write 255 to address zero and address 4 results in 255 at address zero and address 4") then
                set_all_mode(SeqMode, SqiMode, actor, net);
                write_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), std_logic_vector(to_unsigned(0, bus_data_type'length)));
                write_bus_word(net, actor, std_logic_vector(to_unsigned(4, 17)), std_logic_vector(to_unsigned(0, bus_data_type'length)));
                address <= std_logic_vector(to_unsigned(0, address'length));
                write_data <= std_logic_vector(to_unsigned(255, write_data'length));
                rst <= '0';
                ready <= true;
                burst <= '1';
                check(not active);
                request_length <= 4;
                wait until rising_edge(clk) and valid;
                burst <= '0';
                ready <= true;
                address <= std_logic_vector(to_unsigned(4, address'length));
                write_data <= std_logic_vector(to_unsigned(255, write_data'length));
                wait until rising_edge(clk) and valid;
                ready <= false;
                address <= (others => 'X');
                write_data <= (others => 'X');
                wait until rising_edge(cs_n(0));
                read_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), read_data);
                check_equal(read_data, std_logic_vector(to_unsigned(255, read_data'length)));
                read_bus_word(net, actor, std_logic_vector(to_unsigned(4, 17)), read_data);
                check_equal(read_data, std_logic_vector(to_unsigned(255, read_data'length)));
            elsif run("Burst of size 50 works as intended") then
                set_all_mode(SeqMode, SqiMode, actor, net);
                rst <= '0';
                request_length <= 4;
                for i in 0 to 49 loop
                    write_bus_word(net, actor, std_logic_vector(to_unsigned(i*4, 17)), std_logic_vector(to_unsigned(0, bus_data_type'length)));
                end loop;
                for i in 0 to 49 loop
                    address <= std_logic_vector(to_unsigned(i*4, address'length));
                    write_data <= std_logic_vector(to_unsigned(i*17, write_data'length));
                    ready <= true;
                    if i = 49 then
                        burst <= '0';
                    else
                        burst <= '1';
                    end if;
                    if i = 0 then
                        wait until falling_edge(cs_n(0));
                        cs_allowed_all_high <= false;
                    end if;
                    wait until rising_edge(clk) and valid;
                    check_equal(fault, '0');
                end loop;
                ready <= false;
                cs_allowed_all_high <= true;
                wait until rising_edge(cs_n(0));
                for i in 0 to 49 loop
                    read_bus_word(net, actor, std_logic_vector(to_unsigned(i*4, 17)), read_data);
                    check_equal(reorder_nibbles(read_data), std_logic_vector(to_unsigned(i*17, read_data'length)));
                end loop;
            elsif run("Paused burst write 255 to address zero and address 4 results in 255 at address zero and address 4") then
                set_all_mode(SeqMode, SqiMode, actor, net);
                write_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), std_logic_vector(to_unsigned(0, bus_data_type'length)));
                write_bus_word(net, actor, std_logic_vector(to_unsigned(4, 17)), std_logic_vector(to_unsigned(0, bus_data_type'length)));
                address <= std_logic_vector(to_unsigned(0, address'length));
                write_data <= std_logic_vector(to_unsigned(255, write_data'length));
                rst <= '0';
                ready <= true;
                burst <= '1';
                check(not active);
                request_length <= 4;
                wait until rising_edge(clk) and valid;
                ready <= false;
                address <= (others => 'X');
                write_data <= (others => 'X');
                burst <= '0';
                wait for 2 us;
                wait until falling_edge(clk);
                ready <= true;
                address <= std_logic_vector(to_unsigned(4, address'length));
                write_data <= std_logic_vector(to_unsigned(255, write_data'length));
                wait until rising_edge(clk) and valid;
                ready <= false;
                address <= (others => 'X');
                write_data <= (others => 'X');
                check(active);
                wait until not active;
                read_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), read_data);
                check_equal(read_data, std_logic_vector(to_unsigned(255, read_data'length)));
                read_bus_word(net, actor, std_logic_vector(to_unsigned(4, 17)), read_data);
                check_equal(read_data, std_logic_vector(to_unsigned(255, read_data'length)));
            elsif run("A fault ends a burst") then
                set_all_mode(SeqMode, SqiMode, actor, net);
                write_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), std_logic_vector(to_unsigned(0, bus_data_type'length)));
                write_bus_word(net, actor, std_logic_vector(to_unsigned(4, 17)), std_logic_vector(to_unsigned(0, bus_data_type'length)));
                address <= std_logic_vector(to_unsigned(0, address'length));
                write_data <= std_logic_vector(to_unsigned(255, write_data'length));
                request_length <= 4;
                rst <= '0';
                ready <= true;
                burst <= '1';
                wait until rising_edge(clk) and (valid);
                ready <= false;
                wait for clk_period;
                fault <= true;
                wait for clk_period;
                fault <= false;
                wait until not active;
                read_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), read_data);
                check_equal(read_data, std_logic_vector(to_unsigned(255, read_data'length)));
                read_bus_word(net, actor, std_logic_vector(to_unsigned(4, 17)), read_data);
                check_equal(read_data, std_logic_vector(to_unsigned(0, read_data'length)));
            elsif run("After a fault, we can start a new transaction") then
                set_all_mode(SeqMode, SqiMode, actor, net);
                address <= std_logic_vector(to_unsigned(0, address'length));
                write_data <= std_logic_vector(to_unsigned(255, write_data'length));
                request_length <= 4;
                rst <= '0';
                ready <= true;
                burst <= '1';
                wait until rising_edge(clk) and valid;
                ready <= false;
                wait for clk_period;
                fault <= true;
                wait for clk_period;
                fault <= false;
                wait until not active;
                ready <= true;
                wait until rising_edge(clk) and valid;
            elsif run("Active remains asserted until CS = 1") then
                set_all_mode(SeqMode, SqiMode, actor, net);
                address <= std_logic_vector(to_unsigned(0, address'length));
                write_data <= std_logic_vector(to_unsigned(255, write_data'length));
                request_length <= 4;
                rst <= '0';
                ready <= true;
                burst <= '0';
                wait until rising_edge(clk) and valid;
                wait until rising_edge(clk);
                check_equal(active, true);
                ready <= false;
                wait until not active or rising_edge(cs_n(0));
                if cs_n(0) = '0' then
                    check_equal(active, true);
                end if;
                wait until not active;
            elsif run("Write of size 2 works") then
                set_all_mode(SeqMode, SqiMode, actor, net);
                write_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), std_logic_vector(to_unsigned(0, bus_data_type'length)));
                address <= std_logic_vector(to_unsigned(0, address'length));
                write_data <= X"ffffffff";
                request_length <= 2;
                ready <= true;
                burst <= '0';
                rst <= '0';
                wait until rising_edge(clk) and valid;
                ready <= false;
                wait until not active;
                read_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), read_data);
                exp_data := X"0000ffff";
                check_equal(read_data, exp_data);
            elsif run("Write of size 1 works") then
                set_all_mode(SeqMode, SqiMode, actor, net);
                write_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), std_logic_vector(to_unsigned(0, bus_data_type'length)));
                address <= std_logic_vector(to_unsigned(0, address'length));
                write_data <= X"ffffffff";
                request_length <= 1;
                ready <= true;
                burst <= '0';
                rst <= '0';
                wait until rising_edge(clk) and valid;
                ready <= false;
                wait until not active;
                read_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), read_data);
                exp_data := X"000000ff";
                check_equal(read_data, exp_data);
            end if;
        end loop;
        wait for 2*clk_period;
        test_runner_cleanup(runner);
        wait;
    end process;

    process (cs_set)
    begin
        if cs_set = '0' then
            cs_n(0) <= cs_set;
            cs_state <= cs_set after cs_wait_time;
        else
            cs_n(0) <= cs_set after cs_wait_time;
            cs_state <= cs_set after cs_wait_time;
        end if;
    end process;

    process(cs_n, cs_allowed_all_high)
    begin
        if not cs_allowed_all_high then
            check(cs_n /= "111");
        end if;
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

    writer : entity src.triple_23lc1024_writer
    generic map (
        spi_clk_half_period_ticks => spi_clk_half_period_ticks
    )
    port map (
        clk => clk,
        rst => rst,
        spi_clk => sck,
        spi_sio(0) => si_sio0,
        spi_sio(1) => so_sio1,
        spi_sio(2) => sio2,
        spi_sio(3) => hold_n_sio3,
        cs_set => cs_set,
        cs_state => cs_state,
        ready => ready,
        fault => fault,
        valid => valid,
        active => active,
        request_length => request_length,
        address => address,
        cs_request_in => cs_request_in,
        cs_request_out => cs_request_out,
        write_data => write_data,
        burst => burst
    );
end tb;
