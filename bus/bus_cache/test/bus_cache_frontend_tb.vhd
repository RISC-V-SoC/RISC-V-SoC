library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg.all;

entity bus_cache_frontend_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of bus_cache_frontend_tb is
    constant clk_period : time := 20 ns;

    signal clk : std_logic := '0';
    signal rst : boolean := false;

    signal mst2frontend : bus_mst2slv_type;
    signal frontend2mst : bus_slv2mst_type;

    signal address : bus_address_type;
    signal byte_mask : bus_byte_mask_type;
    signal data_out : bus_data_type;
    signal data_in : bus_data_type := (others => '0');
    signal is_read : boolean;
    signal is_write : boolean;

    signal complete_transaction : boolean := false;
    signal error_transaction : boolean := false;
    signal fault_data : bus_fault_type;

begin
    clk <= not clk after (clk_period/2);

    main : process
        variable mst_address : bus_address_type;
        variable mst_byteMask : bus_byte_mask_type;
        variable mst_data : bus_data_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Read requests are announced") then
                mst_address := std_logic_vector(to_unsigned(13, address'length));
                mst_byteMask := (others => '0');
                mst2frontend <= bus_mst2slv_read(address => mst_address, byte_mask => mst_byteMask);
                wait until falling_edge(clk) and is_read;
                check_equal(address, mst_address);
                check_equal(byte_mask, mst_byteMask);
            elsif run("Read requests can be completed") then
                mst_address := std_logic_vector(to_unsigned(13, address'length));
                mst_byteMask := (others => '1');
                mst2frontend <= bus_mst2slv_read(address => mst_address, byte_mask => mst_byteMask);
                wait until rising_edge(clk) and is_read;
                complete_transaction <= true;
                data_in <= std_logic_vector(to_unsigned(42, data_in'length));
                wait until rising_edge(clk);
                complete_transaction <= false;
                check_false(frontend2mst.valid);
                check_false(frontend2mst.fault = '1');
                wait until rising_edge(clk) and frontend2mst.valid;
                check_equal(frontend2mst.readData, data_in);
                check_false(frontend2mst.fault = '1');
            elsif run("Check read after read") then
                mst_address := std_logic_vector(to_unsigned(13, address'length));
                mst_byteMask := (others => '0');
                mst2frontend <= bus_mst2slv_read(address => mst_address, byte_mask => mst_byteMask);
                wait until rising_edge(clk) and is_read;
                complete_transaction <= true;
                data_in <= std_logic_vector(to_unsigned(42, data_in'length));
                wait until rising_edge(clk);
                complete_transaction <= false;
                wait until rising_edge(clk) and frontend2mst.valid;
                mst_address := std_logic_vector(to_unsigned(27, address'length));
                mst_byteMask := (others => '1');
                mst2frontend <= bus_mst2slv_read(address => mst_address, byte_mask => mst_byteMask);
                wait until rising_edge(clk) and is_read;
                wait until falling_edge(clk);
                check_equal(address, mst_address);
                check_equal(byte_mask, mst_byteMask);
            elsif run("Read can finish normally") then
                mst_address := std_logic_vector(to_unsigned(13, address'length));
                mst_byteMask := (others => '1');
                mst2frontend <= bus_mst2slv_read(address => mst_address, byte_mask => mst_byteMask);
                wait until rising_edge(clk) and is_read;
                complete_transaction <= true;
                data_in <= std_logic_vector(to_unsigned(42, data_in'length));
                wait until rising_edge(clk);
                complete_transaction <= false;
                check_false(frontend2mst.valid);
                check_false(frontend2mst.fault = '1');
                wait until falling_edge(clk);
                check_false(is_read);
                wait until rising_edge(clk) and frontend2mst.valid;
                mst2frontend <= BUS_MST2SLV_IDLE;
                check_equal(frontend2mst.readData, data_in);
                check_false(frontend2mst.fault = '1');
                wait until falling_edge(clk);
                check_false(is_read);
            elsif run("Test faulty read") then
                mst_address := std_logic_vector(to_unsigned(13, address'length));
                mst_byteMask := (others => '1');
                mst2frontend <= bus_mst2slv_read(address => mst_address, byte_mask => mst_byteMask);
                wait until rising_edge(clk) and is_read;
                fault_data <= bus_fault_illegal_byte_mask;
                error_transaction <= true;
                wait until rising_edge(clk);
                error_transaction <= false;
                check_false(frontend2mst.fault = '1');
                wait until rising_edge(clk) and frontend2mst.fault = '1';
                mst2frontend <= BUS_MST2SLV_IDLE;
                wait until falling_edge(clk);
                check_false(is_read);
            elsif run("Test write transaction") then
                mst_address := std_logic_vector(to_unsigned(13, address'length));
                mst_byteMask := (others => '1');
                mst_data := std_logic_vector(to_unsigned(42, data_in'length));
                mst2frontend <= bus_mst2slv_write(address => mst_address, write_data => mst_data, byte_mask => mst_byteMask);
                wait until rising_edge(clk) and is_write;
                check_equal(address, mst_address);
                check_equal(byte_mask, mst_byteMask);
                check_equal(data_out, mst_data);
            elsif run("Write can complete") then
                mst_address := std_logic_vector(to_unsigned(13, address'length));
                mst_byteMask := (others => '1');
                mst_data := std_logic_vector(to_unsigned(42, data_in'length));
                mst2frontend <= bus_mst2slv_write(address => mst_address, write_data => mst_data, byte_mask => mst_byteMask);
                wait until rising_edge(clk) and is_write;
                complete_transaction <= true;
                wait until rising_edge(clk);
                complete_transaction <= false;
                check_false(frontend2mst.valid);
                check_false(frontend2mst.fault = '1');
                wait until falling_edge(clk);
                check_false(is_write);
                wait until falling_edge(clk);
                check_false(is_write);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  10 us);

    cache_frontend : entity src.bus_cache_frontend
    port map (
        clk => clk,
        rst => rst,
        mst2frontend => mst2frontend,
        frontend2mst => frontend2mst,
        address => address,
        byte_mask => byte_mask,
        data_out => data_out,
        data_in => data_in,
        is_read => is_read,
        is_write => is_write,
        complete_transaction => complete_transaction,
        error_transaction => error_transaction,
        fault_data => fault_data
    );
end architecture;
