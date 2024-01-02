library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
library tb;
use tb.M23LC1024_pkg;
use tb.triple_23lc1024_tb_pkg;
use src.bus_pkg;

entity triple_23LC1024_controller_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of triple_23LC1024_controller_tb is
    constant clk_period : time := 20 ns;
    constant min_spi_clock_period : time := 50 ns;
    constant min_spi_cs_setup : time := 25 ns;
    constant min_spi_cs_hold : time := 50 ns;
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal cs_n : std_logic_vector(2 downto 0) := (others => '1');
    signal so_sio1 : std_logic;
    signal sio2 : std_logic;
    signal hold_n_sio3 : std_logic;
    signal sck : std_logic;
    signal si_sio0 : std_logic;

    signal mst2slv : bus_pkg.bus_mst2slv_type := bus_pkg.BUS_MST2SLV_IDLE;
    signal slv2mst : bus_pkg.bus_slv2mst_type;

    constant actor_mem0 : actor_t := find("M23LC1024.mem0");
    constant actor_mem1 : actor_t := find("M23LC1024.mem1");
    constant actor_mem2 : actor_t := find("M23LC1024.mem2");
    constant actors : actor_vec_t := (
        actor_mem0,
        actor_mem1,
        actor_mem2
    );

    signal spi_sio_in : std_logic_vector(3 downto 0);
    signal spi_sio_out : std_logic_vector(3 downto 0);
begin
    clk <= not clk after (clk_period/2);

    spi_sio_in <= hold_n_sio3 & sio2 & so_sio1 & si_sio0;
    si_sio0 <= spi_sio_out(0);
    so_sio1 <= spi_sio_out(1);
    sio2 <= spi_sio_out(2);
    hold_n_sio3 <= spi_sio_out(3);

    process
        variable expected_data : bus_pkg.bus_data_type := (others => '0');
        variable read_data : bus_pkg.bus_data_type := (others => '0');
        variable burst_size : natural := 0;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Mems are configured within 10 us") then
                rst <= '1';
                triple_23lc1024_tb_pkg.set_all_mode(M23LC1024_pkg.ByteMode, M23LC1024_pkg.SpiMode, actors, net);
                rst <= '0';
                wait for 10 us;
                triple_23lc1024_tb_pkg.check_all_mode(M23LC1024_pkg.SeqMode, M23LC1024_pkg.SqiMode, actors, net);
            elsif run("Burst read works as intented") then
                rst <= '0';
                triple_23lc1024_tb_pkg.write_bus_word(net, actor_mem0, std_logic_vector(to_unsigned(0, 17)), triple_23lc1024_tb_pkg.reorder_nibbles(X"01020304"));
                triple_23lc1024_tb_pkg.write_bus_word(net, actor_mem0, std_logic_vector(to_unsigned(4, 17)), triple_23lc1024_tb_pkg.reorder_nibbles(X"F1F2F3F4"));
                mst2slv <= bus_pkg.bus_mst2slv_read(std_logic_vector(to_unsigned(0, bus_pkg.bus_address_type'length)), burst => '1');
                expected_data := X"01020304";
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData, expected_data);
                mst2slv <= bus_pkg.bus_mst2slv_read(std_logic_vector(to_unsigned(4, bus_pkg.bus_address_type'length)), burst => '0');
                expected_data := X"F1F2F3F4";
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData, expected_data);
            elsif run("Burst write works as intented") then
                rst <= '0';
                triple_23lc1024_tb_pkg.write_bus_word(net, actor_mem0, std_logic_vector(to_unsigned(0, 17)), (others => '0'));
                triple_23lc1024_tb_pkg.write_bus_word(net, actor_mem0, std_logic_vector(to_unsigned(4, 17)), (others => '0'));
                mst2slv <= bus_pkg.bus_mst2slv_write(std_logic_vector(to_unsigned(0, bus_pkg.bus_address_type'length)),
                                                     triple_23lc1024_tb_pkg.reorder_nibbles(X"01020304"),
                                                     X"F",
                                                     '1');
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_write(std_logic_vector(to_unsigned(4, bus_pkg.bus_address_type'length)),
                                                     triple_23lc1024_tb_pkg.reorder_nibbles(X"f1f2f3f4"),
                                                     X"F",
                                                     '0');
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                wait until rising_edge(cs_n(0));
                expected_data := X"01020304";
                triple_23lc1024_tb_pkg.read_bus_word(net, actor_mem0, std_logic_vector(to_unsigned(0, 17)), read_data);
                check_equal(read_data, expected_data);
                expected_data := X"F1F2F3F4";
                triple_23lc1024_tb_pkg.read_bus_word(net, actor_mem0, std_logic_vector(to_unsigned(4, 17)), read_data);
                check_equal(read_data, expected_data);
            elsif run("Read faults happen when expected") then
                rst <= '0';
                mst2slv <= bus_pkg.bus_mst2slv_read(std_logic_vector(to_unsigned(1, bus_pkg.bus_address_type'length)), burst => '0');
                wait until rising_edge(clk) and bus_pkg.fault_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.faultData, bus_pkg.bus_fault_unaligned_access);
            elsif run("Read after fault aborted read burst works") then
                rst <= '0';
                triple_23lc1024_tb_pkg.write_bus_word(net, actor_mem0, std_logic_vector(to_unsigned(0, 17)), triple_23lc1024_tb_pkg.reorder_nibbles(X"01020304"));
                triple_23lc1024_tb_pkg.write_bus_word(net, actor_mem0, std_logic_vector(to_unsigned(4, 17)), triple_23lc1024_tb_pkg.reorder_nibbles(X"F1F2F3F4"));
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000000", burst => '1');
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000003", byte_mask => "1010");
                wait until rising_edge(clk) and bus_pkg.fault_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                expected_data := X"01020304";
                check_equal(slv2mst.readData, expected_data);
            elsif run("Write after fault aborted write burst works") then
                rst <= '0';
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000000", X"11111111", burst => '1');
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000003", X"11111111", byte_mask => "1010");
                wait until rising_edge(clk) and bus_pkg.fault_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000000", X"ffffffff");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                wait until rising_edge(cs_n(0));
                expected_data := X"ffffffff";
                triple_23lc1024_tb_pkg.read_bus_word(net, actor_mem0, std_logic_vector(to_unsigned(0, 17)), read_data);
                check_equal(read_data, expected_data);
            elsif run("Write faults happen when expected") then
                rst <= '0';
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000001",X"01020304",X"F",'1');
                wait until rising_edge(clk) and bus_pkg.fault_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.faultData, bus_pkg.bus_fault_unaligned_access);
            elsif run("Large bursted write-then-read works as expected") then
                burst_size := 150;
                rst <= '0';
                for i in 0 to burst_size - 1 loop
                    mst2slv <= bus_pkg.bus_mst2slv_write(std_logic_vector(to_unsigned(i*4, bus_pkg.bus_address_type'length)),
                                                        std_logic_vector(to_unsigned(16#7FFFFFFF# - i, bus_pkg.bus_data_type'length)),
                                                        X"F",
                                                        '1');
                    if i = burst_size - 1 then
                        mst2slv.burst <= '0';
                    end if;
                    wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                end loop;
                for i in 0 to burst_size - 1 loop
                    mst2slv <= bus_pkg.bus_mst2slv_read(std_logic_vector(to_unsigned(i*4, bus_pkg.bus_address_type'length)), burst => '1');
                    if i = burst_size - 1 then
                        mst2slv.burst <= '0';
                    end if;
                    wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                    expected_data := std_logic_vector(to_unsigned(16#7FFFFFFF# - i, bus_pkg.bus_data_type'length));
                    check_equal(slv2mst.readData, expected_data);
                end loop;
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
            elsif run ("Writing then reading over all three memories") then
                rst <= '0';
                burst_size := 16;
                for i in 0 to burst_size - 1 loop
                    mst2slv <= bus_pkg.bus_mst2slv_write(std_logic_vector(to_unsigned(i*4, bus_pkg.bus_address_type'length)),
                                                        std_logic_vector(to_unsigned(i, bus_pkg.bus_data_type'length)),
                                                        X"F",
                                                        '0');
                    wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                end loop;
                for i in 0 to burst_size - 1 loop
                    mst2slv <= bus_pkg.bus_mst2slv_write(std_logic_vector(to_unsigned(16#20000# + i*4, bus_pkg.bus_address_type'length)),
                                                        std_logic_vector(to_unsigned(i + burst_size, bus_pkg.bus_data_type'length)),
                                                        X"F",
                                                        '0');
                    wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                end loop;
                for i in 0 to burst_size - 1 loop
                    mst2slv <= bus_pkg.bus_mst2slv_write(std_logic_vector(to_unsigned(16#40000# + i*4, bus_pkg.bus_address_type'length)),
                                                        std_logic_vector(to_unsigned(i + burst_size + burst_size, bus_pkg.bus_data_type'length)),
                                                        X"F",
                                                        '0');
                    wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                end loop;
                -- Now read it back
                for i in 0 to burst_size - 1 loop
                    mst2slv <= bus_pkg.bus_mst2slv_read(std_logic_vector(to_unsigned(i*4, bus_pkg.bus_address_type'length)), burst => '0');
                    wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                    expected_data := std_logic_vector(to_unsigned(i, bus_pkg.bus_data_type'length));
                    check_equal(slv2mst.readData, expected_data);
                end loop;
                for i in 0 to burst_size - 1 loop
                    mst2slv <= bus_pkg.bus_mst2slv_read(std_logic_vector(to_unsigned(16#20000# + i*4, bus_pkg.bus_address_type'length)), burst => '0');
                    wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                    expected_data := std_logic_vector(to_unsigned(i + burst_size, bus_pkg.bus_data_type'length));
                    check_equal(slv2mst.readData, expected_data);
                end loop;
                for i in 0 to burst_size - 1 loop
                    mst2slv <= bus_pkg.bus_mst2slv_read(std_logic_vector(to_unsigned(16#40000# + i*4, bus_pkg.bus_address_type'length)), burst => '0');
                    wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                    expected_data := std_logic_vector(to_unsigned(i + burst_size + burst_size, bus_pkg.bus_data_type'length));
                    check_equal(slv2mst.readData, expected_data);
                end loop;
            elsif run ("Partial write then read works") then
                rst <= '0';
                triple_23lc1024_tb_pkg.write_bus_word(net, actor_mem0, std_logic_vector(to_unsigned(0, 17)), triple_23lc1024_tb_pkg.reorder_nibbles(X"87654321"));
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000000", X"ffffffff", byte_mask => "0001");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                expected_data := X"876543ff";
                check_equal(slv2mst.readData, expected_data);
            elsif run("Partial write mask test") then
                rst <= '0';
                triple_23lc1024_tb_pkg.write_bus_word(net, actor_mem0, std_logic_vector(to_unsigned(0, 17)), triple_23lc1024_tb_pkg.reorder_nibbles(X"00000000"));
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000000", X"ffffffff", byte_mask => "0110");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                expected_data := X"00ffff00";
                check_equal(slv2mst.readData, expected_data);
            end if;
        end loop;
        wait for 2*clk_period;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 1 ms);

    mem_pcb : entity tb.triple_M23LC1024
    port map (
        cs_n => cs_n,
        so_sio1 => so_sio1,
        sio2 => sio2,
        hold_n_sio3 => hold_n_sio3,
        sck => sck,
        si_sio0 => si_sio0
    );

    controller : entity src.triple_23lc1024_controller
    generic map (
        system_clock_period => clk_period,
        min_spi_clock_period => min_spi_clock_period,
        min_spi_cs_setup => min_spi_cs_setup,
        min_spi_cs_hold => min_spi_cs_hold
    ) port map (
        clk => clk,
        rst => rst,
        spi_clk => sck,
        spi_sio_in => spi_sio_in,
        spi_sio_out => spi_sio_out,
        spi_cs => cs_n,
        mst2slv => mst2slv,
        slv2mst => slv2mst
    );


end tb;
