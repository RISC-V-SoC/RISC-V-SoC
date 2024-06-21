library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg;

entity spi_master_device_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of spi_master_device_tb is
    constant clk_period : time := 20 ns;
    signal clk : std_logic := '0';
    signal reset : boolean := false;
    signal spi_mosi_miso : std_logic;
    signal spi_clk : std_logic;
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
            if run("Config defaults to zero") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(2 downto 0), std_logic_vector'("000"));
            elsif run("Enable sticks") then
                address := std_logic_vector(to_unsigned(0, address'length));
                data := std_logic_vector(to_unsigned(1, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000000", byte_mask);
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(0), '1');
            elsif run("CPOL can be updated") then
                address := std_logic_vector(to_unsigned(0, address'length));
                data := std_logic_vector(to_unsigned(2, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000000", byte_mask);
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(1), '1');
            elsif run("CPHA can be updated") then
                address := std_logic_vector(to_unsigned(0, address'length));
                data := std_logic_vector(to_unsigned(4, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000000", byte_mask);
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(2), '1');
            elsif run("CPOL and CPHA cannot be updated when device is already enabled") then
                address := std_logic_vector(to_unsigned(0, address'length));
                data := std_logic_vector(to_unsigned(1, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                address := std_logic_vector(to_unsigned(0, address'length));
                data := std_logic_vector(to_unsigned(6, data'length));
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(2 downto 1), std_logic_vector'("00"));
            elsif run("CPOL, CPHA and enabled can all be set at once") then
                address := std_logic_vector(to_unsigned(0, address'length));
                data := std_logic_vector(to_unsigned(7, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000000", byte_mask);
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(2 downto 0), std_logic_vector'("111"));
            elsif run("Can set/get clock divider") then
                address := std_logic_vector(to_unsigned(8, address'length));
                data := std_logic_vector(to_unsigned(16#1a2b3c4d#, data'length));
                byte_mask := "1111";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(address, byte_mask);
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData, data);
            elsif run("When device is enabled, clock divider cannot be updated") then
                address := std_logic_vector(to_unsigned(0, address'length));
                data := std_logic_vector(to_unsigned(1, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                address := std_logic_vector(to_unsigned(8, address'length));
                data := std_logic_vector(to_unsigned(16#1a2b3c4d#, data'length));
                byte_mask := "1111";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(address, byte_mask);
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData, std_logic_vector'(X"00000000"));
            elsif run("Run a single CPOL = CPHA = 0 transaction") then
                -- Set clock divider to 10
                address := std_logic_vector(to_unsigned(8, address'length));
                data := std_logic_vector(to_unsigned(10, data'length));
                byte_mask := "1111";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Set device enabled
                address := std_logic_vector(to_unsigned(0, address'length));
                data := std_logic_vector(to_unsigned(1, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Set transmit byte 14
                address := std_logic_vector(to_unsigned(1, address'length));
                data := std_logic_vector(to_unsigned(16#14#, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Wait for data available
                loop
                    address := std_logic_vector(to_unsigned(6, address'length));
                    byte_mask := "0011";
                    mst2slv <= bus_pkg.bus_mst2slv_read(address, byte_mask);
                    wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                    exit when slv2mst.readData(15 downto 0) = X"0001";
                end loop;
                address := std_logic_vector(to_unsigned(2, address'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_read(address, byte_mask);
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(7 downto 0), std_logic_vector'(X"14"));
            elsif run("Run two CPOL = CPHA = 0 transaction") then
                -- Set clock divider to 10
                address := std_logic_vector(to_unsigned(8, address'length));
                data := std_logic_vector(to_unsigned(10, data'length));
                byte_mask := "1111";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Set device enabled
                address := std_logic_vector(to_unsigned(0, address'length));
                data := std_logic_vector(to_unsigned(1, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Set transmit bytes
                address := std_logic_vector(to_unsigned(1, address'length));
                data(7 downto 0) := "10101010";
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                loop
                    address := std_logic_vector(to_unsigned(6, address'length));
                    byte_mask := "0011";
                    mst2slv <= bus_pkg.bus_mst2slv_read(address, byte_mask);
                    wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                    exit when slv2mst.readData(15 downto 0) = X"0002";
                end loop;
                address := std_logic_vector(to_unsigned(2, address'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_read(address, byte_mask);
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(7 downto 0), data(7 downto 0));
                mst2slv <= bus_pkg.bus_mst2slv_read(address, byte_mask);
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(7 downto 0), data(7 downto 0));
            elsif run("Run a single CPOL = 1, CPHA = 0 transaction") then
                -- Set clock divider to 10
                address := std_logic_vector(to_unsigned(8, address'length));
                data := std_logic_vector(to_unsigned(10, data'length));
                byte_mask := "1111";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Set device enabled, CPOL to 1
                address := std_logic_vector(to_unsigned(0, address'length));
                data := std_logic_vector(to_unsigned(3, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Set transmit byte 14
                address := std_logic_vector(to_unsigned(1, address'length));
                data := std_logic_vector(to_unsigned(16#14#, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Wait for data available
                loop
                    address := std_logic_vector(to_unsigned(6, address'length));
                    byte_mask := "0011";
                    mst2slv <= bus_pkg.bus_mst2slv_read(address, byte_mask);
                    wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                    exit when slv2mst.readData(15 downto 0) = X"0001";
                end loop;
                address := std_logic_vector(to_unsigned(2, address'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_read(address, byte_mask);
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(7 downto 0), std_logic_vector'(X"14"));
                check_equal(spi_clk, '1');
            elsif run("Run two CPOL = 1, CPHA = 0 transaction") then
                -- Set clock divider to 10
                address := std_logic_vector(to_unsigned(8, address'length));
                data := std_logic_vector(to_unsigned(10, data'length));
                byte_mask := "1111";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Set device enabled, CPOL to 1
                address := std_logic_vector(to_unsigned(0, address'length));
                data := std_logic_vector(to_unsigned(3, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Set transmit bytes
                address := std_logic_vector(to_unsigned(1, address'length));
                data(7 downto 0) := "10101010";
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                loop
                    address := std_logic_vector(to_unsigned(6, address'length));
                    byte_mask := "0011";
                    mst2slv <= bus_pkg.bus_mst2slv_read(address, byte_mask);
                    wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                    exit when slv2mst.readData(15 downto 0) = X"0002";
                end loop;
                address := std_logic_vector(to_unsigned(2, address'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_read(address, byte_mask);
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(7 downto 0), data(7 downto 0));
                mst2slv <= bus_pkg.bus_mst2slv_read(address, byte_mask);
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(7 downto 0), data(7 downto 0));
            elsif run("Reset resets") then
                -- Set device enabled, CPOL to 1
                address := std_logic_vector(to_unsigned(0, address'length));
                data := std_logic_vector(to_unsigned(3, data'length));
                byte_mask := "0001";
                mst2slv <= bus_pkg.bus_mst2slv_write(address, data, byte_mask);
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                reset <= true;
                wait for clk_period;
                reset <= false;
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData(2 downto 0), std_logic_vector'("000"));
            end if;
        end loop;
        wait until rising_edge(clk) or falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 100 us);

    spi_master_device : entity src.spi_master_device
    port map (
        clk => clk,
        reset => reset,
        mosi => spi_mosi_miso,
        miso => spi_mosi_miso,
        spi_clk => spi_clk,
        mst2slv => mst2slv,
        slv2mst => slv2mst
    );
end architecture;
