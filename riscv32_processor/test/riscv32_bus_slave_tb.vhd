library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg.all;
use src.riscv32_pkg.all;

entity riscv32_bus_slave_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_bus_slave_tb is
    constant clk_period : time := 20 ns;

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';

    signal mst2slv : bus_mst2slv_type := BUS_MST2SLV_IDLE;
    signal slv2mst : bus_slv2mst_type := BUS_SLV2MST_IDLE;

    signal address_to_ci : natural range 0 to 31;
    signal write_to_ci : boolean;
    signal data_to_ci :  riscv32_data_type;
    signal data_from_ci :  riscv32_data_type := (others => '0');

    signal address_to_regFile : natural range 0 to 31;
    signal write_to_regFile : boolean;
    signal data_to_regFile :  riscv32_data_type;
    signal data_from_regFile :  riscv32_data_type := (others => '0');

    signal valid_latch : boolean := false;

begin

    clk <= not clk after (clk_period/2);

    main : process
        variable actualAddress : std_logic_vector(bus_address_type'range);
        variable writeValue : riscv32_data_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Bus slave errors on unaligned address") then
                actualAddress := X"00000001";
                mst2slv <= bus_mst2slv_read(address => actualAddress);
                wait until rising_edge(clk) and any_transaction(mst2slv, slv2mst);
                check(fault_transaction(mst2slv, slv2mst));
                check_equal(slv2mst.faultData, bus_fault_unaligned_access);
            elsif run("Errors on bytemask /= 1111") then
                actualAddress := X"00000000";
                mst2slv <= bus_mst2slv_read(address => actualAddress, byte_mask => "0101");
                wait until rising_edge(clk) and any_transaction(mst2slv, slv2mst);
                check(fault_transaction(mst2slv, slv2mst));
                check_equal(slv2mst.faultData, bus_fault_illegal_byte_mask);
            elsif run("Finishes a transaction") then
                actualAddress := X"00000000";
                mst2slv <= bus_mst2slv_read(address => actualAddress, byte_mask => "0101");
                wait until rising_edge(clk) and any_transaction(mst2slv, slv2mst);
                mst2slv <= BUS_MST2SLV_IDLE;
                wait until rising_edge(clk);
                check(slv2mst.fault = '0');
            elsif run("Read works") then
                actualAddress := X"00000014";
                mst2slv <= bus_mst2slv_read(address => actualAddress);
                wait until address_to_ci = 5;
                check(not write_to_ci);
                check(not write_to_regFile);
                data_from_ci <= X"01234567";
                wait until rising_edge(clk) and read_transaction(mst2slv, slv2mst);
                check_equal(data_from_ci, slv2mst.readData);
            elsif run("Write works") then
                actualAddress := X"00000070";
                writeValue := X"AABBCCDD";
                mst2slv <= bus_mst2slv_write(address => actualAddress, write_data => writeValue);
                wait until address_to_ci = 28;
                check(write_to_ci);
                check(not write_to_regFile);
                check(data_to_ci = writeValue);
                wait until rising_edge(clk) and write_transaction(mst2slv, slv2mst);
            elsif run("write_to_ci is only active for 1 cycle") then
                actualAddress := X"00000070";
                writeValue := X"AABBCCDD";
                mst2slv <= bus_mst2slv_write(address => actualAddress, write_data => writeValue);
                wait until rising_edge(clk) and write_to_ci;
                wait until rising_edge(clk);
                check(not write_to_ci);
            elsif run("rst works") then
                actualAddress := X"00000014";
                mst2slv <= bus_mst2slv_read(address => actualAddress);
                wait until rising_edge(clk);
                rst <= '1';
                wait for 25*clk_period;
                check(not valid_latch);
            elsif run("Read from address 0x84 reads from regFile address 1") then
                actualAddress := X"00000084";
                mst2slv <= bus_mst2slv_read(address => actualAddress);
                wait until address_to_regFile = 1;
                check(not write_to_ci);
                check(not write_to_regFile);
                data_from_regFile <= X"01234567";
                wait until rising_edge(clk) and read_transaction(mst2slv, slv2mst);
                check_equal(data_from_regFile, slv2mst.readData);
            elsif run("Write to address 0x84 writes to regFile address 1") then
                actualAddress := X"00000084";
                writeValue := X"AABBCCDD";
                mst2slv <= bus_mst2slv_write(address => actualAddress, write_data => writeValue);
                wait until address_to_regFile = 1;
                check(not write_to_ci);
                check(write_to_regFile);
                check(data_to_regFile = writeValue);
                wait until rising_edge(clk) and write_transaction(mst2slv, slv2mst);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    process(slv2mst)
    begin
        if slv2mst.valid then
            valid_latch <= true;
        end if;
    end process;

    test_runner_watchdog(runner,  1 us);

    bus_slave : entity src.riscv32_bus_slave
    port map (
        clk => clk,
        rst => rst,
        mst2slv => mst2slv,
        slv2mst => slv2mst,
        address_to_ci => address_to_ci,
        write_to_ci => write_to_ci,
        data_to_ci => data_to_ci,
        data_from_ci => data_from_ci,
        address_to_regFile => address_to_regFile,
        write_to_regFile => write_to_regFile,
        data_to_regFile => data_to_regFile,
        data_from_regFile => data_from_regFile
    );
end architecture;
