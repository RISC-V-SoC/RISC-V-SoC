library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg;
use src.debug_module_pkg;
use src.debug_module_address_pkg.all;

library tb;
use tb.simulated_bus_memory_pkg;

entity debug_module_director_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of debug_module_director_tb is
    constant slaveActor : actor_t := new_actor("slave");

    constant clk_period : time := 20 ns;
    signal clk : std_logic := '0';
    signal bus_master_reset : boolean := false;

    signal dmi2dm : debug_module_pkg.debug_module_bus_mst2slv_type := debug_module_pkg.DEBUG_MODULE_BUS_MST2SLV_IDLE;
    signal dm2dmi : debug_module_pkg.debug_module_bus_slv2mst_type;

    signal dm2bus : bus_pkg.bus_mst2slv_type;
    signal bus2dm : bus_pkg.bus_slv2mst_type := bus_pkg.BUS_SLV2MST_IDLE;

    signal dm2csr : bus_pkg.bus_mst2slv_type;
    signal csr2dm : bus_pkg.bus_slv2mst_type := bus_pkg.BUS_SLV2MST_IDLE;

    signal halt_hart : boolean;
    signal hart_halted : boolean := false;

    pure function convert_address(
        in_val : natural
    ) return debug_module_pkg.debug_module_bus_address_type is
    begin
        return std_ulogic_vector(to_unsigned(in_val, debug_module_pkg.debug_module_bus_address_type'length));
    end function;

    pure function fuzzy_equal(
        actual : debug_module_pkg.debug_module_bus_data_type;
        expected : debug_module_pkg.debug_module_bus_data_type
    ) return boolean is
    begin
        for i in expected'range loop
            if expected(i) /= '-' and expected(i) /= actual(i) then
                return false;
            end if;
        end loop;
        return true;
    end function;

    procedure check_equal_fuzzy(
        constant actual   : debug_module_pkg.debug_module_bus_data_type;
        constant expected : debug_module_pkg.debug_module_bus_data_type
    ) is
        variable masked_actual   : debug_module_pkg.debug_module_bus_data_type;
        variable masked_expected : debug_module_pkg.debug_module_bus_data_type;
    begin
        masked_actual   := actual;
        masked_expected := expected;

        for i in expected'range loop
            if expected(i) = '-' then
                masked_actual(i)   := '0';
                masked_expected(i) := '0';
            end if;
        end loop;

        check_equal(
            got => std_logic_vector(masked_actual),
            expected => std_logic_vector(masked_expected)
        );
    end procedure;

    procedure read_register(
        signal toDM : inout debug_module_pkg.debug_module_bus_mst2slv_type;
        signal fromDM : in debug_module_pkg.debug_module_bus_slv2mst_type;
        constant address : in natural) is
    begin
        toDM <= debug_module_pkg.debug_module_bus_mst2slv_read(convert_address(address));
        wait until rising_edge(clk) and debug_module_pkg.debug_module_bus_read_transaction(toDM, fromDM);
    end procedure;

    procedure read_register_fuzzy_check(
        signal toDM : inout debug_module_pkg.debug_module_bus_mst2slv_type;
        signal fromDM : in debug_module_pkg.debug_module_bus_slv2mst_type;
        constant address : in natural;
        constant expected : in debug_module_pkg.debug_module_bus_data_type
    ) is
    begin
        read_register(toDM, fromDM, address);
        check_equal_fuzzy(fromDM.readData, expected);
    end procedure;

    procedure read_register_check(
        signal toDM : inout debug_module_pkg.debug_module_bus_mst2slv_type;
        signal fromDM : in debug_module_pkg.debug_module_bus_slv2mst_type;
        constant address : in natural;
        constant expected : in debug_module_pkg.debug_module_bus_data_type
    ) is
    begin
        read_register(toDM, fromDM, address);
        check_equal(
            got => std_logic_vector(fromDm.readData),
            expected => std_logic_vector(expected)
        );
    end procedure;

    procedure read_register_fuzzy_check(
        signal toDM : inout debug_module_pkg.debug_module_bus_mst2slv_type;
        signal fromDM : in debug_module_pkg.debug_module_bus_slv2mst_type;
        constant address : in natural;
        constant expected : in natural
    ) is
        variable act_expected : debug_module_pkg.debug_module_bus_data_type;
    begin
        act_expected := std_ulogic_vector(to_unsigned(expected, act_expected'length));
        read_register_fuzzy_check(toDm, fromDm, address, act_expected);
    end procedure;

    procedure read_register_until_fuzzy(
        signal toDM : inout debug_module_pkg.debug_module_bus_mst2slv_type;
        signal fromDM : in debug_module_pkg.debug_module_bus_slv2mst_type;
        constant address : in natural;
        constant expected : in debug_module_pkg.debug_module_bus_data_type
    ) is
    begin
        toDM <= debug_module_pkg.debug_module_bus_mst2slv_read(convert_address(address));
        wait until rising_edge(clk) and debug_module_pkg.debug_module_bus_read_transaction(toDM, fromDM) and fuzzy_equal(fromDM.readData, expected);
    end procedure;

    procedure write_register(
        signal toDM : inout debug_module_pkg.debug_module_bus_mst2slv_type;
        signal fromDM : in debug_module_pkg.debug_module_bus_slv2mst_type;
        constant address : in natural;
        data : in debug_module_pkg.debug_module_bus_data_type) is
    begin
        toDM <= debug_module_pkg.debug_module_bus_mst2slv_write(convert_address(address), data);
        wait until rising_edge(clk) and debug_module_pkg.debug_module_bus_write_transaction(toDM, fromDM);
    end procedure;

    procedure activate_debugmodule(
        signal toDM : inout debug_module_pkg.debug_module_bus_mst2slv_type;
        signal fromDM : in debug_module_pkg.debug_module_bus_slv2mst_type) is
    begin
        write_register(toDm, fromDm, dmcontrol_address, (others => '0'));
        read_register_until_fuzzy(toDm, fromDm, dmcontrol_address, (0 => '0', others => '-'));
        write_register(toDm, fromDm, dmcontrol_address, (0 => '1', others => '0'));
        read_register_until_fuzzy(toDm, fromDm, dmcontrol_address, (0 => '1', others => '-'));
        toDm <= debug_module_pkg.DEBUG_MODULE_BUS_MST2SLV_IDLE;
    end procedure;

begin
    clk <= not clk after (clk_period/2);
    process
        variable readData : debug_module_pkg.debug_module_bus_data_type;
        variable simulated_read_data : bus_pkg.bus_data_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("debug module can be enabled") then
                activate_debugmodule(dmi2dm, dm2dmi);
            elsif run("Out of range read returns all zeros") then
                activate_debugmodule(dmi2dm, dm2dmi);
                read_register_check(dmi2dm, dm2dmi, 16#80#, X"00000000");
                read_register_check(dmi2dm, dm2dmi, 16#0#, X"00000000");
            elsif run("check dmstatus version") then
                activate_debugmodule(dmi2dm, dm2dmi);
                read_register_fuzzy_check(dmi2dm, dm2dmi, dmstatus_address, 3);
            elsif run ("Check sbcs status") then
                activate_debugmodule(dmi2dm, dm2dmi);
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (31 downto 29 => "001", others => '-'));
            elsif run("Check bus read flow") then
                activate_debugmodule(dmi2dm, dm2dmi);
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000000", X"11111111", X"f");
                write_register(dmi2dm, dm2dmi, sbcs_address, (sbreadonaddr_msb =>  '1', 19 downto 17 => "010", others => '0'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, (others => '0'));
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '1', others => '-'));
                read_register_until_fuzzy(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
                check(dm2dmi.readData(sberror_msb downto sberror_lsb) = "000");
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbdata0_address, X"11111111");
            elsif run("If sbreadonaddr is not set, there is no read when address is written") then
                activate_debugmodule(dmi2dm, dm2dmi);
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000000", X"11111111", X"f");
                write_register(dmi2dm, dm2dmi, sbcs_address, (19 downto 17 => "010", others => '0'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, (others => '0'));
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
            elsif run("If the debug module is never activated, there is no read when address is written") then
                write_register(dmi2dm, dm2dmi, sbcs_address, (sbreadonaddr_msb =>  '1', 19 downto 17 => "010", others => '0'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, (others => '0'));
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
            elsif run("When an out-of-range address is accessed, sberror is set to 2") then
                activate_debugmodule(dmi2dm, dm2dmi);
                write_register(dmi2dm, dm2dmi, sbcs_address, (sbreadonaddr_msb =>  '1', 19 downto 17 => "010", others => '0'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, X"0f000000");
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '1', others => '-'));
                read_register_until_fuzzy(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
                check(dm2dmi.readData(sberror_msb downto sberror_lsb) = "010");
            elsif run("When an unaligned access occurs, sberror is set to 3") then
                activate_debugmodule(dmi2dm, dm2dmi);
                write_register(dmi2dm, dm2dmi, sbcs_address, (sbreadonaddr_msb =>  '1', 19 downto 17 => "010", others => '0'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, X"00000001");
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '1', others => '-'));
                read_register_until_fuzzy(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
                check(dm2dmi.readData(sberror_msb downto sberror_lsb) = "011");
            elsif run("Writing 0 to sberror does not clear the error") then
                activate_debugmodule(dmi2dm, dm2dmi);
                write_register(dmi2dm, dm2dmi, sbcs_address, (sbreadonaddr_msb =>  '1', 19 downto 17 => "010", others => '0'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, X"0f000000");
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '1', others => '-'));
                read_register_until_fuzzy(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
                check(dm2dmi.readData(sberror_msb downto sberror_lsb) = "010");
                write_register(dmi2dm, dm2dmi, sbcs_address, (sbreadonaddr_msb => '1', sbaccess_msb downto sbaccess_lsb => "010", sberror_msb downto sberror_lsb => '0', others => '0'));
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sberror_msb downto sberror_lsb => "010", others => '-'));
            elsif run("Writing 1 to sberror does clear the error") then
                activate_debugmodule(dmi2dm, dm2dmi);
                write_register(dmi2dm, dm2dmi, sbcs_address, (sbreadonaddr_msb =>  '1', 19 downto 17 => "010", others => '0'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, X"0f000000");
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '1', others => '-'));
                read_register_until_fuzzy(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
                check(dm2dmi.readData(sberror_msb downto sberror_lsb) = "010");
                write_register(dmi2dm, dm2dmi, sbcs_address, (sbreadonaddr_msb => '1', sbaccess_msb downto sbaccess_lsb => "010", sberror_msb downto sberror_lsb => "001", others => '0'));
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sberror_msb downto sberror_lsb => "000", others => '-'));
            elsif run("If sberror is nonzero, no new reads can start") then
                activate_debugmodule(dmi2dm, dm2dmi);
                write_register(dmi2dm, dm2dmi, sbcs_address, (sbreadonaddr_msb =>  '1', 19 downto 17 => "010", others => '0'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, X"0f000000");
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '1', others => '-'));
                read_register_until_fuzzy(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
                check(dm2dmi.readData(sberror_msb downto sberror_lsb) = "010");
                write_register(dmi2dm, dm2dmi, sbaddress0_address, X"0f000000");
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
            elsif run("If sberror is not 0, sbdata0 cannot be updated") then
                activate_debugmodule(dmi2dm, dm2dmi);
                write_register(dmi2dm, dm2dmi, sbcs_address, (sbreadonaddr_msb =>  '1', 19 downto 17 => "010", others => '0'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, X"0f000000");
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '1', others => '-'));
                read_register_until_fuzzy(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
                check(dm2dmi.readData(sberror_msb downto sberror_lsb) = "010");
                write_register(dmi2dm, dm2dmi, sbdata0_address, X"01010101");
                read_register(dmi2dm, dm2dmi, sbdata0_address);
                check_false(dm2dmi.readData = X"01010101");
            elsif run("If a transaction ends in error, sbdata0 is not updated") then
                activate_debugmodule(dmi2dm, dm2dmi);
                write_register(dmi2dm, dm2dmi, sbcs_address, (sbreadonaddr_msb =>  '1', 19 downto 17 => "010", others => '0'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, X"0f000000");
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '1', others => '-'));
                read_register_until_fuzzy(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
                check(dm2dmi.readData(sberror_msb downto sberror_lsb) = "010");
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbdata0_address, X"00000000");
            elsif run("Do a size 8 read") then
                activate_debugmodule(dmi2dm, dm2dmi);
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000000", X"11111111", X"f");
                write_register(dmi2dm, dm2dmi, sbcs_address, (sbreadonaddr_msb =>  '1', 19 downto 17 => "000", others => '0'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, (others => '0'));
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '1', others => '-'));
                read_register_until_fuzzy(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
                check(dm2dmi.readData(sberror_msb downto sberror_lsb) = "000");
                read_register_check(dmi2dm, dm2dmi, sbdata0_address, X"------11");
            elsif run("A 64 bit read leads to no bus activity and sberror = 4") then
                activate_debugmodule(dmi2dm, dm2dmi);
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000000", X"11111111", X"f");
                write_register(dmi2dm, dm2dmi, sbcs_address, (sbreadonaddr_msb =>  '1', 19 downto 17 => "011", others => '0'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, (others => '0'));
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
                check(dm2dmi.readData(sberror_msb downto sberror_lsb) = "100");
            elsif run("Starting a read during a read leads to sbbusyerror = 1 and finishes the original transaction") then
                activate_debugmodule(dmi2dm, dm2dmi);
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000000", X"11111111", X"f");
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000004", X"22222222", X"f");
                write_register(dmi2dm, dm2dmi, sbcs_address, (sbreadonaddr_msb =>  '1', 19 downto 17 => "010", others => '0'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, (others => '0'));
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '1', others => '-'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, X"00000004");
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusyerror_msb => '1', others => '-'));
                read_register_until_fuzzy(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbdata0_address, X"11111111");
            elsif run("sbbusyerror cannot be cleared by writing zero") then
                activate_debugmodule(dmi2dm, dm2dmi);
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000000", X"11111111", X"f");
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000004", X"22222222", X"f");
                write_register(dmi2dm, dm2dmi, sbcs_address, (sbreadonaddr_msb =>  '1', 19 downto 17 => "010", others => '0'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, (others => '0'));
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '1', others => '-'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, X"00000004");
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusyerror_msb => '1', others => '-'));
                read_register_until_fuzzy(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
                write_register(dmi2dm, dm2dmi, sbcs_address, (sbbusyerror_msb => '0', sbreadonaddr_msb =>  '1', 19 downto 17 => "010", others => '0'));
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusyerror_msb => '1', others => '-'));
            elsif run("sbbusyerror can be cleared by writing one") then
                activate_debugmodule(dmi2dm, dm2dmi);
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000000", X"11111111", X"f");
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000004", X"22222222", X"f");
                write_register(dmi2dm, dm2dmi, sbcs_address, (sbreadonaddr_msb =>  '1', 19 downto 17 => "010", others => '0'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, (others => '0'));
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '1', others => '-'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, X"00000004");
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusyerror_msb => '1', others => '-'));
                read_register_until_fuzzy(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
                write_register(dmi2dm, dm2dmi, sbcs_address, (sbbusyerror_msb => '1', sbreadonaddr_msb =>  '1', 19 downto 17 => "010", others => '0'));
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusyerror_msb => '0', others => '-'));
            elsif run("No transaction can be started while sbbusyerror = 1") then
                activate_debugmodule(dmi2dm, dm2dmi);
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000000", X"11111111", X"f");
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000004", X"22222222", X"f");
                write_register(dmi2dm, dm2dmi, sbcs_address, (sbreadonaddr_msb =>  '1', 19 downto 17 => "010", others => '0'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, (others => '0'));
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '1', others => '-'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, X"00000004");
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusyerror_msb => '1', others => '-'));
                read_register_until_fuzzy(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, X"00000004");
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
            elsif run("If sbautoincrement is set and sbaccess is 32 bit, then after a read sbaddress0 is incremented by 4") then
                activate_debugmodule(dmi2dm, dm2dmi);
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000000", X"11111111", X"f");
                write_register(dmi2dm, dm2dmi, sbcs_address, (sbreadonaddr_msb =>  '1', 19 downto 17 => "010", sbautoincrement_msb => '1', others => '0'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, (others => '0'));
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '1', others => '-'));
                read_register_until_fuzzy(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
                check(dm2dmi.readData(sberror_msb downto sberror_lsb) = "000");
                read_register_check(dmi2dm, dm2dmi, sbdata0_address, X"11111111");
                read_register_check(dmi2dm, dm2dmi, sbaddress0_address, X"00000004");
            elsif run("If sbautoincrement is set and sbaccess is 16 bit, then after a read sbaddress0 is incremented by 2") then
                activate_debugmodule(dmi2dm, dm2dmi);
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000000", X"11111111", X"f");
                write_register(dmi2dm, dm2dmi, sbcs_address, (sbreadonaddr_msb =>  '1', 19 downto 17 => "001", sbautoincrement_msb => '1', others => '0'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, (others => '0'));
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '1', others => '-'));
                read_register_until_fuzzy(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
                check(dm2dmi.readData(sberror_msb downto sberror_lsb) = "000");
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbdata0_address, X"----1111");
                read_register_check(dmi2dm, dm2dmi, sbaddress0_address, X"00000002");
            elsif run("If sbautoincrement and sbreadondata is set, new reads start automatically on the next address") then
                activate_debugmodule(dmi2dm, dm2dmi);
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000000", X"11111111", X"f");
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000004", X"22222222", X"f");
                write_register(dmi2dm, dm2dmi, sbcs_address, (sbreadonaddr_msb =>  '1', 19 downto 17 => "010", sbautoincrement_msb => '1', sbreadondata_msb => '1', others => '0'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, (others => '0'));
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '1', others => '-'));
                read_register_until_fuzzy(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
                check(dm2dmi.readData(sberror_msb downto sberror_lsb) = "000");
                read_register_check(dmi2dm, dm2dmi, sbdata0_address, X"11111111");
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '1', others => '-'));
                read_register_until_fuzzy(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
                read_register_check(dmi2dm, dm2dmi, sbdata0_address, X"22222222");
            elsif run("Test write flow") then
                activate_debugmodule(dmi2dm, dm2dmi);
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000000", X"11111111", X"f");
                write_register(dmi2dm, dm2dmi, sbcs_address, (19 downto 17 => "010", others => '0'));
                write_register(dmi2dm, dm2dmi, sbaddress0_address, (others => '0'));
                write_register(dmi2dm, dm2dmi, sbdata0_address, X"12121212");
                read_register_fuzzy_check(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '1', others => '-'));
                read_register_until_fuzzy(dmi2dm, dm2dmi, sbcs_address, (sbbusy_msb => '0', others => '-'));
                simulated_bus_memory_pkg.read_from_address(net, slaveActor, X"00000000", simulated_read_data);
                check_equal(simulated_read_data, std_logic_vector'(X"12121212"));
            end if;
        end loop;
        wait until rising_edge(clk) or falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 1 ms);

    debug_module_director : entity src.debug_module_director
    port map (
        clk => clk,
        bus_master_reset => bus_master_reset,
        dmi2dm => dmi2dm,
        dm2dmi => dm2dmi,
        dm2bus => dm2bus,
        bus2dm => bus2dm,
        dm2csr => dm2csr,
        csr2dm => csr2dm,
        halt_hart => halt_hart,
        hart_halted => hart_halted
    );

    bus_slave : entity tb.simulated_bus_memory
    generic map (
        depth_log2b => 4,
        allow_unaligned_access => false,
        actor => slaveActor,
        read_delay => 4,
        write_delay => 5,
        fault_delay => 5
    ) port map (
        clk => clk,
        mst2mem => dm2bus,
        mem2mst => bus2dm
    );
end architecture;
