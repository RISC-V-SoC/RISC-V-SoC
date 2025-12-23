library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg;

entity platform_level_interrupt_controller_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of platform_level_interrupt_controller_tb is
    constant clk_period : time := 20 ns;
    signal clk : std_logic := '0';
    signal reset : boolean := false;
    signal mst2slv : bus_pkg.bus_mst2slv_type := bus_pkg.BUS_MST2SLV_IDLE;
    signal slv2mst : bus_pkg.bus_slv2mst_type;
    signal interrupt_signal : boolean_vector(3 downto 1) := (others => false);
    signal interrupt_notification : boolean_vector(3 downto 0);
begin
    clk <= not clk after (clk_period/2);
    process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Reading interrupt 0 prio returns 0") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(to_integer(unsigned(slv2mst.readData)), 0);
            elsif run("Set and read priority of interrupt 1") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000004", X"00000001");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000004");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(to_integer(unsigned(slv2mst.readData)), 1);
            elsif run("Only relevant priority bits are set") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000004", X"ffff0000");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000004");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(to_integer(unsigned(slv2mst.readData)), 0);
            elsif run("Writes to priority registers of non-existing interrupt sources have no effect") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000100", X"00000001");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000100");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(to_integer(unsigned(slv2mst.readData)), 0);
            elsif run("Writes to priority register of interrupt source 0 have no effect") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000000", X"00000001");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(to_integer(unsigned(slv2mst.readData)), 0);
            elsif run("If interrupt 1 is signaled, interrupt source 1 is pending") then
                interrupt_signal(1) <= true;
                wait until rising_edge(clk);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00001000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check(slv2mst.readData(1) = '1');
            elsif run("If all interrupt inputs are signaled, interrupt source 0 is not pending") then
                interrupt_signal <= (others => true);
                wait until rising_edge(clk);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00001000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check(slv2mst.readData(0) = '0');
            elsif run("If no interrupts are signaled, no interrupt is pending") then
                interrupt_signal <= (others => false);
                wait until rising_edge(clk);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00001000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check(or_reduce(slv2mst.readData(4 downto 0)) = '0');
            elsif run("Interrupts since unsignaled are still pending") then
                interrupt_signal(1) <= true;
                wait until rising_edge(clk);
                interrupt_signal(1) <= false;
                wait until rising_edge(clk);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00001000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check(slv2mst.readData(1) = '1');
            elsif run("Enable all interrupts for context 1") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00002080", X"ffffffff");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00002080");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check(and_reduce(slv2mst.readData(3 downto 1)) = '1');
                check(slv2mst.readData(0) = '0');
                check(or_reduce(slv2mst.readData(7 downto 5)) = '0');
            elsif run("Enable all interrupts for a non-existing context") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"001F1FFC", X"ffffffff");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"001F1FFC");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                -- The return value here is not interesting as it can be anything. We just want it not to crash.
            elsif run("Enable an interrupt for context 2") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00002100", X"00000002");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00002100");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check(slv2mst.readData(0) = '0');
                check(slv2mst.readData(1) = '1');
                check(or_reduce(slv2mst.readData(7 downto 2)) = '0');
            elsif run("Set and read priority treshold") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00200000", X"0000abcd");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00200000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData, std_logic_vector'(X"0000abcd"));
            elsif run("Priority treshold is clipped correctly") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00200000", X"ffffabcd");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00200000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData, std_logic_vector'(X"0000abcd"));
            elsif run("Set priority treshold for non-existing context") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"03FFF000", X"0000abcd");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"03FFF000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                -- The return value here is not interesting as it can be anything. We just want it not to crash.
            elsif run("Operating on priority treshold + 8 has no effect") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00200008", X"0000abcd");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00200000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData, std_logic_vector'(X"00000000"));
            elsif run("Route interrupt 1 to context 0") then
                -- Set the priority of interrupt 1
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000004", X"ffffffff");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Enable interrupt 1 for context 0
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00002000", X"00000002");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- For completeness, set the priority treshold of context 0
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00200000", X"00000000");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                -- Now signal interrupt 1
                interrupt_signal(1) <= true;
                wait until rising_edge(clk) and interrupt_notification(0);
            elsif run("Interrupt should not occur if interrupt priority is too low") then
                -- Set the priority of interrupt 1
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000004", X"00000001");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Enable interrupt 1 for context 0
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00002000", X"00000002");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Set the priority treshold of context 0
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00200000", X"00000001");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                -- Now signal interrupt 1
                interrupt_signal(1) <= true;
                wait for 5*clk_period;
                check_false(interrupt_notification(0));
            elsif run("Interrupt should not occur if interrupt is not enabled for that context") then
                -- Set the priority of interrupt 1
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000004", X"00000001");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Disable all interrupts for context 0
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00002000", X"00000000");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Set the priority treshold of context 0
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00200000", X"00000000");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                -- Now signal interrupt 1
                interrupt_signal(1) <= true;
                wait for 5*clk_period;
                check_false(interrupt_notification(0));
            elsif run("Interrupt should not occur if interrupt is not pending") then
                -- Set the priority of interrupt 1
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000004", X"00000001");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Enable interrupt 1 for context 0
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00002000", X"00000002");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Set the priority treshold of context 0
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00200000", X"00000000");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                -- Now dont signal interrupt 1
                interrupt_signal(1) <= false;
                wait for 5*clk_period;
                check_false(interrupt_notification(0));
            elsif run("If an interrupt is enabled for all contexts, all contexts should be notified") then
                -- Set the priority of interrupt 1
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000004", X"00000001");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Enable interrupt 1 for all contexts
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00002000", X"00000002");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00002080", X"00000002");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00002100", X"00000002");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00002180", X"00000002");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Set the priority tresholds of all contexts
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00200000", X"00000000");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00201000", X"00000000");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00202000", X"00000000");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00203000", X"00000000");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                -- Now signal interrupt 1
                interrupt_signal(1) <= true;
                wait for 5*clk_period;
                check_true(interrupt_notification(0));
                check_true(interrupt_notification(1));
                check_true(interrupt_notification(2));
                check_true(interrupt_notification(3));
            elsif run("Context 0 is told the index of the interrupting source") then
                -- Set the priority of interrupt 1
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000004", X"ffffffff");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Enable interrupt 1 for context 0
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00002000", X"00000002");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- For completeness, set the priority treshold of context 0
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00200000", X"00000000");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                -- Now signal interrupt 1
                interrupt_signal(1) <= true;
                wait until rising_edge(clk) and interrupt_notification(0);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00200004");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData, std_logic_vector'(X"00000001"));
            elsif run("Interrupts can be claimed and masked") then
                -- Set the priority of interrupt 1
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000004", X"ffffffff");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Enable interrupt 1 for context 0
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00002000", X"00000002");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- For completeness, set the priority treshold of context 0
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00200000", X"00000000");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                -- Now signal interrupt 1
                interrupt_signal(1) <= true;
                wait until rising_edge(clk) and interrupt_notification(0);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00200004");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData, std_logic_vector'(X"00000001"));
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                wait until rising_edge(clk) and not interrupt_notification(0);
            elsif run("Unaligned access results in the right error") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00200005");
                wait until rising_edge(clk) and bus_pkg.any_transaction(mst2slv, slv2mst);
                check(slv2mst.fault = '1');
                check(slv2mst.faultData = bus_pkg.bus_fault_unaligned_access);
            elsif run("An incomplete bytemask results in the right error") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00200004", byte_mask => "1010");
                wait until rising_edge(clk) and bus_pkg.any_transaction(mst2slv, slv2mst);
                check(slv2mst.fault = '1');
                check(slv2mst.faultData = bus_pkg.bus_fault_illegal_byte_mask);
            elsif run("If no interrupt is pending for a context, then the claimable interrupt is 0") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00200004");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData, std_logic_vector'(X"00000000"));
            elsif run("The highest priority pending interrupt is claimed") then
                -- Set the priority of interrupt 1
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000004", X"00000001");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Set the priority of interrupt 2
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000008", X"00000002");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Enable interrupts 1 and 2 for context 0
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00002000", X"00000006");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- For completeness, set the priority treshold of context 0
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00200000", X"00000000");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                -- Now signal interrupts 1 and 2
                interrupt_signal(1) <= true;
                interrupt_signal(2) <= true;
                wait until rising_edge(clk) and interrupt_notification(0);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00200004");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData, std_logic_vector'(X"00000002"));
            elsif run("Interrupts can only be claimed once") then
                -- Set the priority of interrupt 1
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000004", X"ffffffff");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Enable interrupt 1 for contexts 0 and 1
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00002000", X"00000002");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00002080", X"00000002");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- For completeness, set the priority treshold of contexts 0 and 1
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00200000", X"00000000");
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00201000", X"00000000");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                -- Now signal interrupt 1
                interrupt_signal(1) <= true;
                wait until rising_edge(clk) and interrupt_notification(0) and interrupt_notification(1);
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00200004");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData, std_logic_vector'(X"00000001"));
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00201004");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData, std_logic_vector'(X"00000000"));
            elsif run("Interrupts can be completed") then
                -- Set the priority of interrupt 1
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000004", X"ffffffff");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Enable interrupt 1 for context 0
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00002000", X"00000002");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- For completeness, set the priority treshold of context 0
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00200000", X"00000000");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                -- Now signal interrupt 1
                interrupt_signal(1) <= true;
                wait until rising_edge(clk) and interrupt_notification(0);
                -- Claim interrupt 1
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00200004");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData, std_logic_vector'(X"00000001"));
                -- unsignal interrupt 1
                interrupt_signal(1) <= false;
                -- Complete interrupt 1
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00200004", X"00000001");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Make sure its no longer pending
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00001000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check(slv2mst.readData(1) = '0');
            elsif run("Completed interrupts can be pending again") then
                -- Set the priority of interrupt 1
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000004", X"ffffffff");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Enable interrupt 1 for context 0
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00002000", X"00000002");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- For completeness, set the priority treshold of context 0
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00200000", X"00000000");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                -- Now signal interrupt 1
                interrupt_signal(1) <= true;
                wait until rising_edge(clk) and interrupt_notification(0);
                -- Claim interrupt 1
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00200004");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData, std_logic_vector'(X"00000001"));
                -- unsignal interrupt 1
                interrupt_signal(1) <= false;
                -- Complete interrupt 1
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00200004", X"00000001");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Make sure its no longer pending
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00001000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check(slv2mst.readData(1) = '0');
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                check(not interrupt_notification(0));
                -- Now signal interrupt 1
                interrupt_signal(1) <= true;
                wait until rising_edge(clk) and interrupt_notification(0);
                -- Claim interrupt 1
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00200004");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData, std_logic_vector'(X"00000001"));
            elsif run("Completing interrupt 0 is a no-op") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00200004", X"00000000");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
            elsif run("Completing a non-existing interrupt is a no-op") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00200004", X"000003ff");
            elsif run("A claimed interrupt is no longer pending") then
                -- Set the priority of interrupt 1
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000004", X"ffffffff");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Enable interrupt 1 for context 0
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00002000", X"00000002");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- For completeness, set the priority treshold of context 0
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00200000", X"00000000");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                -- Now signal interrupt 1
                interrupt_signal(1) <= true;
                wait until rising_edge(clk) and interrupt_notification(0);
                -- Claim interrupt 1
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00200004");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check_equal(slv2mst.readData, std_logic_vector'(X"00000001"));
                -- Check if interrupt 1 is no longer pending
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00001000");
                wait until rising_edge(clk) and bus_pkg.read_transaction(mst2slv, slv2mst);
                check(slv2mst.readData(1) = '0');
            elsif run("An interrupt cannot be completed by a context for which it is not enabled") then
                -- Set the priority of interrupt 1
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000004", X"ffffffff");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- Enable interrupt 1 for context 0
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00002000", X"00000002");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                -- For completeness, set the priority treshold of context 0
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00200000", X"00000000");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                -- Now signal interrupt 1
                interrupt_signal(1) <= true;
                wait until rising_edge(clk) and interrupt_notification(0);
                interrupt_signal(1) <= false;
                -- Complete interrupt 1 from context 1
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00201004", X"00000001");
                wait until rising_edge(clk) and bus_pkg.write_transaction(mst2slv, slv2mst);
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                wait for 5*clk_period;
                check(interrupt_notification(0));
            end if;
        end loop;
        wait until rising_edge(clk) or falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 100 us);

    platform_level_interrupt_controller : entity src.platform_level_interrupt_controller
    generic map (
        context_count => 4,
        interrupt_source_count => 4,
        interrupt_priority_level_count_log2b => 16
    ) port map (
        clk => clk,
        reset => reset,
        mst2slv => mst2slv,
        slv2mst => slv2mst,
        interrupt_signal_from_source => interrupt_signal,
        interrupt_notification_to_context => interrupt_notification
    );
end architecture;
