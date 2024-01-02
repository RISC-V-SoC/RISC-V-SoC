library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg;

entity uart_bus_slave_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of uart_bus_slave_tb is
    constant uart_master_bfm : uart_master_t := new_uart_master(initial_baud_rate => 115200);
    constant uart_master_stream : stream_master_t := as_stream(uart_master_bfm);
    constant uart_slave_bfm : uart_slave_t := new_uart_slave(initial_baud_rate => 115200);
    constant uart_slave_stream : stream_slave_t := as_stream(uart_slave_bfm);
    constant clk_period : time := 20 ns;
    signal clk : std_logic := '0';
    signal reset : boolean := false;
    signal rx : std_logic := '0';
    signal tx : std_logic;
    signal mst2slv : bus_pkg.bus_mst2slv_type := bus_pkg.BUS_MST2SLV_IDLE;
    signal slv2mst : bus_pkg.bus_slv2mst_type;
begin
    clk <= not clk after (clk_period/2);
    process
        variable address : bus_pkg.bus_address_type;
        variable data : bus_pkg.bus_data_type;
        variable byte_mask : bus_pkg.bus_byte_mask_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Test single word tx") then
                -- First, set baudrate. We want 115200, at 50 MHz, this means 434 as the baud divisor
                address := std_logic_vector(to_unsigned(8, address'length));
                data := std_logic_vector(to_unsigned(434, data'length));
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Enable the transmit side
                address := std_logic_vector(to_unsigned(1, address'length));
                data := std_logic_vector(to_unsigned(1, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Now try to transmit a word
                address := std_logic_vector(to_unsigned(0, address'length));
                data := std_logic_vector(to_unsigned(16#AB#, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                check_stream(net, uart_slave_stream, X"AB");
            elsif run("Write then read clock baud divider") then
                address := std_logic_vector(to_unsigned(8, address'length));
                data := std_logic_vector(to_unsigned(434, data'length));
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(address);
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData, data);
            elsif run("TX enabled is false by default") then
                address := std_logic_vector(to_unsigned(1, address'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_read(address, byte_mask);
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(0), '0');
            elsif run("TX enabled can be set and read back") then
                address := std_logic_vector(to_unsigned(1, address'length));
                byte_mask := "0001";
                data := std_logic_vector(to_unsigned(1, data'length));
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(address, byte_mask);
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(7 downto 0), std_logic_vector'(X"01"));
            elsif run("Test two word tx") then
                -- First, set baudrate. We want 115200, at 50 MHz, this means 434 as the baud divisor
                address := std_logic_vector(to_unsigned(8, address'length));
                data := std_logic_vector(to_unsigned(434, data'length));
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Enable the transmit side
                address := std_logic_vector(to_unsigned(1, address'length));
                data := std_logic_vector(to_unsigned(1, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Setup first word
                address := std_logic_vector(to_unsigned(0, address'length));
                data := std_logic_vector(to_unsigned(16#AB#, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Setup second word
                address := std_logic_vector(to_unsigned(0, address'length));
                data := std_logic_vector(to_unsigned(16#AC#, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                check_stream(net, uart_slave_stream, X"AB");
                check_stream(net, uart_slave_stream, X"AC");
            elsif run("Test tx queue count") then
                -- Enable the transmit side
                address := std_logic_vector(to_unsigned(1, address'length));
                data := std_logic_vector(to_unsigned(1, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Setup first word
                address := std_logic_vector(to_unsigned(0, address'length));
                data := std_logic_vector(to_unsigned(16#AB#, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Setup second word
                address := std_logic_vector(to_unsigned(0, address'length));
                data := std_logic_vector(to_unsigned(16#AC#, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                address := std_logic_vector(to_unsigned(4, address'length));
                byte_mask := "0011";
                mst2slv <= bus_pkg.bus_mst2slv_read(address, byte_mask);
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                -- 1, because the first word is already popped and being transmitted
                check_equal(slv2mst.readData(15 downto 0), std_logic_vector(to_unsigned(1, 16)));
            elsif run("RX transmission works") then
                -- First, set baudrate. We want 115200, at 50 MHz, this means 434 as the baud divisor
                address := std_logic_vector(to_unsigned(8, address'length));
                data := std_logic_vector(to_unsigned(434, data'length));
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Enable the receive side
                address := std_logic_vector(to_unsigned(3, address'length));
                data := std_logic_vector(to_unsigned(1, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                push_stream(net, uart_master_stream, X"12");
                data := (others => '0');
                while data(15 downto 0) /= std_logic_vector(to_unsigned(1, 16)) loop
                    address := std_logic_vector(to_unsigned(6, address'length));
                    byte_mask := "0011";
                    mst2slv <= bus_pkg.bus_mst2slv_read(address, byte_mask);
                    wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                    data := slv2mst.readData;
                end loop;
                -- Pop response
                address := std_logic_vector(to_unsigned(2, address'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_read(address, byte_mask);
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(7 downto 0), std_logic_vector'(X"12"));
                -- Check if queue is now empty
                address := std_logic_vector(to_unsigned(6, address'length));
                byte_mask := "0011";
                mst2slv <= bus_pkg.bus_mst2slv_read(address, byte_mask);
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(15 downto 0), std_logic_vector'(X"0000"));
            elsif run("Four RX transmissions") then
                -- First, set baudrate. We want 115200, at 50 MHz, this means 434 as the baud divisor
                address := std_logic_vector(to_unsigned(8, address'length));
                data := std_logic_vector(to_unsigned(434, data'length));
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Enable the receive side
                address := std_logic_vector(to_unsigned(3, address'length));
                data := std_logic_vector(to_unsigned(1, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                push_stream(net, uart_master_stream, X"12");
                push_stream(net, uart_master_stream, X"34");
                push_stream(net, uart_master_stream, X"56");
                push_stream(net, uart_master_stream, X"78");
                while data(15 downto 0) /= std_logic_vector(to_unsigned(4, 16)) loop
                    address := std_logic_vector(to_unsigned(6, address'length));
                    byte_mask := "0011";
                    mst2slv <= bus_pkg.bus_mst2slv_read(address, byte_mask);
                    wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                    data := slv2mst.readData;
                end loop;
                -- Pop responses
                address := std_logic_vector(to_unsigned(2, address'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_read(address, byte_mask);
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(7 downto 0), std_logic_vector'(X"12"));
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(7 downto 0), std_logic_vector'(X"34"));
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(7 downto 0), std_logic_vector'(X"56"));
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(7 downto 0), std_logic_vector'(X"78"));
            elsif run("Reset resets") then
                -- Enable the transceiver
                address := std_logic_vector(to_unsigned(1, address'length));
                data := X"00010001";
                byte_mask := "0101";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Check if transceiving is enabled
                address := std_logic_vector(to_unsigned(1, address'length));
                byte_mask := "0101";
                mst2slv <= bus_pkg.bus_mst2slv_read(address, byte_mask);
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(0), '1');
                check_equal(slv2mst.readData(16), '1');
                -- Now reset the system
                reset <= true;
                wait until rising_edge(clk);
                reset <= false;
                address := std_logic_vector(to_unsigned(1, address'length));
                byte_mask := "0101";
                mst2slv <= bus_pkg.bus_mst2slv_read(address, byte_mask);
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(0), '0');
                check_equal(slv2mst.readData(16), '0');
            end if;
        end loop;
        wait until rising_edge(clk) or falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 1 ms);

    uart_bus_slave : entity src.uart_bus_slave
    port map (
        clk => clk,
        reset => reset,
        rx => rx,
        tx => tx,
        mst2slv => mst2slv,
        slv2mst => slv2mst
    );

    uart_master : entity vunit_lib.uart_master
    generic map (
      uart => uart_master_bfm)
    port map (
      tx => rx);

    uart_slave : entity vunit_lib.uart_slave
    generic map (
      uart => uart_slave_bfm)
    port map (
      rx => tx);
end architecture;
