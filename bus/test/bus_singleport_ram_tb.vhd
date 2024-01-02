library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg.all;

entity bus_singleport_ram_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of bus_singleport_ram_tb is

    type mem_type is record
        rst : std_logic;
        mst2slv : bus_mst2slv_type;
        slv2mst : bus_slv2mst_type;
        done : boolean;
        success : boolean;
    end record;

    constant MEM_TYPE_DEFAULT : mem_type := (
        rst => '0',
        mst2slv => BUS_MST2SLV_IDLE,
        slv2mst => BUS_SLV2MST_IDLE,
        done => false,
        success => false
    );
    constant clk_period : time := 20 ns;

    signal mem_256_byte_control : mem_type := MEM_TYPE_DEFAULT;
    signal mem_32_byte_control : mem_type := MEM_TYPE_DEFAULT;

    signal clk : std_logic := '0';
begin

    clk <= not clk after (clk_period/2);

    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run ("test_write_then_read") then
                wait until falling_edge(clk);
                mem_256_byte_control.mst2slv <= bus_mst2slv_write(address => std_logic_vector(to_unsigned(16, bus_address_type'length)),
                                                                  write_data => std_logic_vector(to_unsigned(14, bus_data_type'length)),
                                                                  byte_mask => (others => '1'));
                wait until rising_edge(clk) and write_transaction(mem_256_byte_control.mst2slv, mem_256_byte_control.slv2mst);
                mem_256_byte_control.mst2slv <= bus_mst2slv_write(address => std_logic_vector(to_unsigned(24, bus_address_type'length)),
                                                                  write_data => std_logic_vector(to_unsigned(15, bus_data_type'length)),
                                                                  byte_mask => (others => '1'));
                wait until rising_edge(clk) and write_transaction(mem_256_byte_control.mst2slv, mem_256_byte_control.slv2mst);
                mem_256_byte_control.mst2slv <= bus_mst2slv_read(address => std_logic_vector(to_unsigned(16, bus_address_type'length)));
                wait until rising_edge(clk) and read_transaction(mem_256_byte_control.mst2slv, mem_256_byte_control.slv2mst);
                check_equal(to_integer(unsigned(mem_256_byte_control.slv2mst.readData)), 14);
                mem_256_byte_control.mst2slv <= bus_mst2slv_write(address => std_logic_vector(to_unsigned(16, bus_address_type'length)),
                                                                  write_data => std_logic_vector(to_unsigned(20, bus_data_type'length)),
                                                                  byte_mask => (others => '0'));
                wait until rising_edge(clk) and write_transaction(mem_256_byte_control.mst2slv, mem_256_byte_control.slv2mst);
                mem_256_byte_control.mst2slv <= bus_mst2slv_read(address => std_logic_vector(to_unsigned(16, bus_address_type'length)));
                wait until rising_edge(clk) and read_transaction(mem_256_byte_control.mst2slv, mem_256_byte_control.slv2mst);
                check_equal(14, to_integer(unsigned(mem_256_byte_control.slv2mst.readData)));
            elsif run("Test address space mirroring") then
                mem_32_byte_control.mst2slv <= bus_mst2slv_write(address => std_logic_vector(to_unsigned(0, bus_address_type'length)),
                                                                  write_data => std_logic_vector(to_unsigned(14, bus_data_type'length)),
                                                                  byte_mask => (others => '1'));
                wait until rising_edge(clk) and write_transaction(mem_32_byte_control.mst2slv, mem_32_byte_control.slv2mst);
                mem_32_byte_control.mst2slv <= bus_mst2slv_read(address => std_logic_vector(to_unsigned(32, bus_address_type'length)));
                wait until rising_edge(clk) and read_transaction(mem_32_byte_control.mst2slv, mem_32_byte_control.slv2mst);
                check_equal(14, to_integer(unsigned(mem_32_byte_control.slv2mst.readData)));
            elsif run("Test unaligned access error") then
                mem_32_byte_control.mst2slv <= bus_mst2slv_write(address => std_logic_vector(to_unsigned(1, bus_address_type'length)),
                                                                  write_data => std_logic_vector(to_unsigned(14, bus_data_type'length)),
                                                                  byte_mask => (others => '1'));
                wait until rising_edge(clk) and fault_transaction(mem_32_byte_control.mst2slv, mem_32_byte_control.slv2mst);
                check_equal(bus_fault_unaligned_access, mem_32_byte_control.slv2mst.faultData);
                mem_32_byte_control.mst2slv <= bus_mst2slv_write(address => std_logic_vector(to_unsigned(0, bus_address_type'length)),
                                                                  write_data => std_logic_vector(to_unsigned(14, bus_data_type'length)),
                                                                  byte_mask => (others => '1'));
                wait until rising_edge(clk) and write_transaction(mem_32_byte_control.mst2slv, mem_32_byte_control.slv2mst);
                mem_32_byte_control.mst2slv <= bus_mst2slv_read(address => std_logic_vector(to_unsigned(2, bus_address_type'length)));
                wait until rising_edge(clk) and fault_transaction(mem_32_byte_control.mst2slv, mem_32_byte_control.slv2mst);
            end if;
        end loop;
        wait until rising_edge(clk) or falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 10 ms);

    mem_256_byte : entity src.bus_singleport_ram
    generic map (
        DEPTH_LOG2B => 8
    )
    port map (
        rst => mem_256_byte_control.rst,
        clk => clk,
        mst2mem => mem_256_byte_control.mst2slv,
        mem2mst => mem_256_byte_control.slv2mst
    );

    mem_32_byte : entity src.bus_singleport_ram
    generic map (
        DEPTH_LOG2B => 4
    )
    port map (
        rst => mem_32_byte_control.rst,
        clk => clk,
        mst2mem => mem_32_byte_control.mst2slv,
        mem2mst => mem_32_byte_control.slv2mst
    );
end architecture;
