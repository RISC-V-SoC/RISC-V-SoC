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

entity triple_23LC1024_reader_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of triple_23LC1024_reader_tb is
    constant spi_clk_half_period_ticks : natural := 2;
    constant clk_period : time := 20 ns;
    constant cs_wait_time : time := 50 ns;
    signal clk : std_logic := '0';
    signal rst : boolean := true;

    signal cs_n : std_logic_vector(2 downto 0) := (others => '1');
    signal so_sio1 : std_logic;
    signal sio2 : std_logic;
    signal hold_n_sio3 : std_logic;
    signal sck : std_logic;
    signal si_sio0 : std_logic;

    signal active : boolean;
    signal ready :  boolean := false;
    signal valid : boolean;
    signal request_length : positive range 1 to bus_bytes_per_word;
    signal address : std_logic_vector(16 downto 0) := (others => '0');
    signal read_data : bus_data_type := (others => '0');
    signal burst : std_logic := '0';
    signal fault : boolean := false;

    signal cs_set : std_logic;
    signal cs_state : std_logic;

    signal spi_sio_in : std_logic_vector(3 downto 0);
    signal spi_sio_out : std_logic_vector(3 downto 0);

    signal reading : boolean;

    signal cs_request_in : cs_request_type := request_none;
    signal cs_request_out : cs_request_type;

begin
    clk <= not clk after (clk_period/2);

    spi_sio_in <= hold_n_sio3 & sio2 & so_sio1 & si_sio0;
    process(reading, spi_sio_out)
    begin
        if not reading then
            si_sio0 <= spi_sio_out(0);
            so_sio1 <= spi_sio_out(1);
            sio2 <= spi_sio_out(2);
            hold_n_sio3 <= spi_sio_out(3);
        else
            si_sio0 <= 'Z';
            so_sio1 <= 'Z';
            sio2 <= 'Z';
            hold_n_sio3 <= 'Z';
        end if;
    end process;

    process
        constant actor : actor_t := find("M23LC1024.mem0");
        variable exp_data : bus_data_type := (others => '0');
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Bus data width should be a multiple of 8") then
                -- We send our data packages in multiples of 8 bit, therefore the bus width
                -- has to be at least 8 bit.
                check(bus_data_width_log2b >= 3);
            elsif run("Read from address zero which contains 255 results in 255") then
                set_all_mode(SeqMode, SqiMode, actor, net);
                write_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), reorder_nibbles(std_logic_vector(to_unsigned(255, bus_data_type'length))));
                address <= std_logic_vector(to_unsigned(0, address'length));
                rst <= false;
                ready <= true;
                burst <= '0';
                request_length <= 4;
                wait until rising_edge(clk) and valid;
                ready <= false;
                address <= (others => 'X');
                check_equal(read_data, std_logic_vector(to_unsigned(255, bus_data_type'length)));
                check(active);
                wait until rising_edge(clk);
                check_equal('0', valid);
                wait until not active;
            elsif run("Read from address zero which contains 0xFFFEFDFC results in 0xFFFEFDFC") then
                set_all_mode(SeqMode, SqiMode, actor, net);
                exp_data := X"FFFEFDFC";
                write_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), reorder_nibbles(exp_data));
                address <= std_logic_vector(to_unsigned(0, address'length));
                rst <= false;
                ready <= true;
                burst <= '0';
                request_length <= 4;
                wait until rising_edge(clk) and valid;
                ready <= false;
                address <= (others => 'X');
                check_equal(read_data, exp_data);
                check(active);
                wait until rising_edge(clk);
                check_equal('0', valid);
                wait until not active;
            elsif run("Read from address zero which contains 254 and address 4 which contains 14 results in 254, 14") then
                set_all_mode(SeqMode, SqiMode, actor, net);
                write_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), reorder_nibbles(std_logic_vector(to_unsigned(254, bus_data_type'length))));
                write_bus_word(net, actor, std_logic_vector(to_unsigned(4, 17)), reorder_nibbles(std_logic_vector(to_unsigned(14, bus_data_type'length))));
                address <= std_logic_vector(to_unsigned(0, address'length));
                rst <= false;
                ready <= true;
                burst <= '0';
                request_length <= 4;
                wait until rising_edge(clk) and valid;
                check_equal(read_data, std_logic_vector(to_unsigned(254, bus_data_type'length)));
                address <= std_logic_vector(to_unsigned(4, address'length));
                ready <= true;
                wait until rising_edge(clk) and valid;
                check_equal(read_data, std_logic_vector(to_unsigned(14, bus_data_type'length)));
                ready <= false;
                address <= (others => 'X');
                check(active);
                wait until not active;
            elsif run("Burst read from address zero which contains 254 and address 4 which contains 14 results in 254, 14") then
                set_all_mode(SeqMode, SqiMode, actor, net);
                write_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), reorder_nibbles(std_logic_vector(to_unsigned(254, bus_data_type'length))));
                write_bus_word(net, actor, std_logic_vector(to_unsigned(4, 17)), reorder_nibbles(std_logic_vector(to_unsigned(14, bus_data_type'length))));
                address <= std_logic_vector(to_unsigned(0, address'length));
                rst <= false;
                ready <= true;
                burst <= '1';
                request_length <= 4;
                wait until rising_edge(clk) and valid;
                check_equal(read_data, std_logic_vector(to_unsigned(254, bus_data_type'length)));
                address <= std_logic_vector(to_unsigned(4, address'length));
                burst <= '0';
                ready <= true;
                wait until rising_edge(clk) and valid;
                check_equal(read_data, std_logic_vector(to_unsigned(14, bus_data_type'length)));
                ready <= false;
                address <= (others => 'X');
                check(active);
                wait until not active;
            elsif run("Paused burst read from address zero which contains 254 and address 4 which contains 14 results in 254, 14") then
                set_all_mode(SeqMode, SqiMode, actor, net);
                write_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), reorder_nibbles(std_logic_vector(to_unsigned(254, bus_data_type'length))));
                write_bus_word(net, actor, std_logic_vector(to_unsigned(4, 17)), reorder_nibbles(std_logic_vector(to_unsigned(14, bus_data_type'length))));
                address <= std_logic_vector(to_unsigned(0, address'length));
                rst <= false;
                ready <= true;
                burst <= '1';
                request_length <= 4;
                wait until rising_edge(clk) and valid;
                check_equal(read_data, std_logic_vector(to_unsigned(254, bus_data_type'length)));
                address <= std_logic_vector(to_unsigned(4, address'length));
                burst <= '0';
                ready <= false;
                wait for 2 us;
                wait until falling_edge(clk);
                ready <= true;
                wait until rising_edge(clk) and valid;
                check_equal(read_data, std_logic_vector(to_unsigned(14, bus_data_type'length)));
                ready <= false;
                address <= (others => 'X');
                check(active);
                wait until not active;
            elsif run("Errors end burst") then
                set_all_mode(SeqMode, SqiMode, actor, net);
                write_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), std_logic_vector(to_unsigned(254, bus_data_type'length)));
                write_bus_word(net, actor, std_logic_vector(to_unsigned(4, 17)), std_logic_vector(to_unsigned(14, bus_data_type'length)));
                address <= std_logic_vector(to_unsigned(0, address'length));
                rst <= false;
                ready <= true;
                burst <= '1';
                request_length <= 4;
                wait until rising_edge(clk) and valid;
                ready <= false;
                wait for clk_period;
                fault <= true;
                wait for clk_period;
                fault <= false;
                wait until rising_edge(cs_n(0));
            elsif run("Active remains asserted until CS = 1") then
                set_all_mode(SeqMode, SqiMode, actor, net);
                address <= std_logic_vector(to_unsigned(0, address'length));
                rst <= false;
                ready <= true;
                request_length <= 4;
                wait until rising_edge(clk) and valid;
                wait until rising_edge(clk);
                check_equal(active, true);
                ready <= false;
                wait until not active or rising_edge(cs_n(0));
                if cs_n(0) = '0' then
                    check_equal(active, true);
                end if;
                wait until not active;
            elsif run("Read of size 2 works") then
                set_all_mode(SeqMode, SqiMode, actor, net);
                write_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), reorder_nibbles(X"87654321"));
                address <= std_logic_vector(to_unsigned(0, address'length));
                rst <= false;
                ready <= true;
                burst <= '0';
                request_length <= 2;
                wait until rising_edge(clk) and valid;
                exp_data := X"00004321";
                check_equal(read_data, exp_data);
            elsif run("Read of size 1 works") then
                set_all_mode(SeqMode, SqiMode, actor, net);
                write_bus_word(net, actor, std_logic_vector(to_unsigned(0, 17)), reorder_nibbles(X"87654321"));
                address <= std_logic_vector(to_unsigned(0, address'length));
                rst <= false;
                ready <= true;
                burst <= '0';
                request_length <= 1;
                wait until rising_edge(clk) and valid;
                exp_data := X"00000021";
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

    reader : entity src.triple_23lc1024_reader
    generic map (
        spi_clk_half_period_ticks => spi_clk_half_period_ticks
    )
    port map (
        clk => clk,
        rst => rst,
        spi_clk => sck,
        spi_sio_in => spi_sio_in,
        spi_sio_out => spi_sio_out,
        cs_set => cs_set,
        cs_state => cs_state,
        ready => ready,
        valid => valid,
        active => active,
        fault => fault,
        reading => reading,
        request_length => request_length,
        address => address,
        cs_request_in => cs_request_in,
        cs_request_out => cs_request_out,
        read_data => read_data,
        burst => burst
    );
end tb;
