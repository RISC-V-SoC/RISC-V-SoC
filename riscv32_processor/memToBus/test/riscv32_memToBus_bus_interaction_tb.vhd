library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library tb;
use tb.simulated_bus_memory_pkg;

library src;
use src.bus_pkg.all;

entity riscv32_memToBus_bus_interaction_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_memToBus_bus_interaction_tb is
    constant clk_period : time := 20 ns;
    signal clk : std_logic := '0';
    signal rst : boolean := false;

    signal mst2slv : bus_mst2slv_type;
    signal slv2mst : bus_slv2mst_type := BUS_SLV2MST_IDLE;

    signal readAddress : bus_address_type := (others => '0');
    signal writeAddress : bus_address_type := (others => '0');
    signal readByteMask : bus_byte_mask_type := (others => '0');
    signal writeByteMask : bus_byte_mask_type := (others => '0');
    signal doRead : boolean := false;
    signal doWrite : boolean := false;
    signal dataIn : bus_data_type := (others => '0');

    signal busy : boolean;
    signal completed : boolean;
    signal fault : boolean;
    signal dataOut : bus_data_type;
    signal faultData : bus_fault_type;
begin
    clk <= not clk after (clk_period/2);

    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Test read request") then
                readAddress <= X"01020304";
                readByteMask <= (others => '1');
                doRead <= true;
                doWrite <= false;
                wait until rising_edge(clk) and bus_requesting(mst2slv);
                check_true(mst2slv.readReady = '1');
                check_equal(mst2slv.address, readAddress);
                check_equal(mst2slv.byteMask, readByteMask);
                check(busy);
                wait for 10*clk_period;
                slv2mst.readData <= X"11223344";
                slv2mst.valid <= true;
                slv2mst.fault <= '0';
                wait until rising_edge(clk);
                slv2mst.valid <= false;
                wait until falling_edge(clk);
                check(mst2slv.readReady = '0');
                wait until rising_edge(clk) and completed;
                check_false(busy);
                check_false(fault);
                check_equal(dataOut, slv2mst.readData);
                wait until rising_edge(clk);
                check_false(completed);
            elsif run("Test write request") then
                writeAddress <= X"01020304";
                writeByteMask <= "0110";
                dataIn <= X"112233FF";
                doRead <= false;
                doWrite <= true;
                wait until rising_edge(clk) and bus_requesting(mst2slv);
                check_true(mst2slv.writeReady = '1');
                check_equal(mst2slv.address, writeAddress);
                check_equal(mst2slv.byteMask, writeByteMask);
                check_equal(mst2slv.writeData, dataIn);
                wait for 10*clk_period;
                slv2mst.valid <= true;
                slv2mst.fault <= '0';
                wait until rising_edge(clk);
                slv2mst.valid <= false;
                wait until falling_edge(clk);
                check(mst2slv.writeReady = '0');
                wait until rising_edge(clk) and completed;
                check_false(busy);
                check_false(fault);
                wait until rising_edge(clk);
                check_false(completed);
            elsif run("Test fault transaction") then
                writeAddress <= X"01020304";
                writeByteMask <= "0110";
                dataIn <= X"112233FF";
                doRead <= false;
                doWrite <= true;
                wait until rising_edge(clk) and bus_requesting(mst2slv);
                slv2mst.valid <= false;
                slv2mst.fault <= '1';
                slv2mst.faultData <= bus_fault_illegal_byte_mask;
                wait until rising_edge(clk);
                slv2mst.valid <= false;
                wait until falling_edge(clk);
                check(mst2slv.writeReady = '0');
                wait until rising_edge(clk) and completed;
                check_true(fault);
                wait until rising_edge(clk);
                check_false(completed);
            elsif run("Test rst") then
                writeAddress <= X"01020304";
                writeByteMask <= "0110";
                dataIn <= X"112233FF";
                doRead <= false;
                doWrite <= true;
                wait until rising_edge(clk) and bus_requesting(mst2slv);
                rst <= true;
                doWrite <= false;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check(not bus_requesting(mst2slv));
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 us);

    interactor : entity src.riscv32_memToBus_bus_interaction
    port map (
        clk => clk,
        rst => rst,
        mst2slv => mst2slv,
        slv2mst => slv2mst,
        readAddress => readAddress,
        writeAddress => writeAddress,
        readByteMask => readByteMask,
        writeByteMask => writeByteMask,
        doRead => doRead,
        doWrite => doWrite,
        dataIn => dataIn,
        busy => busy,
        completed => completed,
        fault => fault,
        dataOut => dataOut,
        faultData => faultData
    );
end architecture;
