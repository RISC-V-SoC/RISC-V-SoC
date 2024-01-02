library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.riscv32_pkg.all;

entity riscv32_pipeline_forwarding_unit_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_pipeline_forwarding_unit_tb is
    signal rs1DataFromID : riscv32_data_type := (others => '0');
    signal rs1AddressFromID : riscv32_registerFileAddress_type := 0;
    signal rs2DataFromID : riscv32_data_type := (others => '0');
    signal rs2AddressFromID : riscv32_registerFileAddress_type := 0;

    signal regDataFromEx : riscv32_data_type := (others => '0');
    signal regAddressFromEx : riscv32_registerFileAddress_type := 0;
    signal regWriteFromEx : boolean := false;

    signal regDataFromMem : riscv32_data_type := (others => '0');
    signal regAddressFromMem : riscv32_registerFileAddress_type := 0;
    signal regWriteFromMem : boolean := false;

    signal rs1Data : riscv32_data_type;
    signal rs2Data : riscv32_data_type;
begin
    main : process
        variable expectedRsData : riscv32_data_type;
        variable expectedRtData : riscv32_data_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Regdata is forwarded when no other stage regWrites") then
                expectedRsData := X"0000000A";
                expectedRtData := X"0000000B";
                rs1DataFromID <= expectedRsData;
                rs1AddressFromID <= 1;
                rs2DataFromID <= expectedRtData;
                rs2AddressFromID <= 1;
                wait for 1 ns;
                check_equal(rs1Data, expectedRsData);
                check_equal(rs2Data, expectedRtData);
            elsif run("RegData is forwarded from mem stage") then
                expectedRsData := X"0000000A";
                expectedRtData := expectedRsData;
                rs1AddressFromID <= 5;
                rs2AddressFromID <= 5;
                regDataFromMem <= expectedRsData;
                regAddressFromMem <= 5;
                regWriteFromMem <= true;
                wait for 1 ns;
                check_equal(rs1Data, expectedRsData);
                check_equal(rs2Data, expectedRtData);
            elsif run("RegData is not forwarded if addressFromMem is different") then
                expectedRsData := X"0000000A";
                expectedRtData := expectedRsData;
                rs1AddressFromID <= 5;
                rs2AddressFromID <= 5;
                rs1DataFromID <= expectedRsData;
                rs2DataFromID <= expectedRtData;
                regAddressFromMem <= 6;
                regWriteFromMem <= true;
                wait for 1 ns;
                check_equal(rs1Data, expectedRsData);
                check_equal(rs2Data, expectedRtData);
            elsif run("RegData from ex is prefered over mem") then
                expectedRsData := X"0000000A";
                expectedRtData := expectedRsData;
                rs1AddressFromID <= 5;
                rs2AddressFromID <= 5;
                regAddressFromMem <= 5;
                regWriteFromMem <= true;
                regDataFromEx <= expectedRsData;
                regAddressFromEx <= 5;
                regWriteFromEx <= true;
                wait for 1 ns;
                check_equal(rs1Data, expectedRsData);
                check_equal(rs2Data, expectedRtData);
            elsif run("RegData from ex is not prefered if address differs") then
                expectedRsData := X"0000000A";
                expectedRtData := expectedRsData;
                rs1AddressFromID <= 5;
                rs2AddressFromID <= 5;
                regDataFromMem <= expectedRsData;
                regAddressFromMem <= 5;
                regWriteFromMem <= true;
                regAddressFromEx <= 6;
                regWriteFromEx <= true;
                wait for 1 ns;
                check_equal(rs1Data, expectedRsData);
                check_equal(rs2Data, expectedRtData);
            elsif run("RegData is not forwarded for address 0") then
                expectedRsData := X"00000000";
                expectedRtData := expectedRsData;
                regDataFromMem <= (others => '1');
                regDataFromEx <= (others => '1');
                rs1AddressFromID <= 0;
                rs2AddressFromID <= 0;
                regAddressFromMem <= 0;
                regWriteFromMem <= true;
                regAddressFromEx <= 0;
                regWriteFromEx <= true;
                wait for 1 ns;
                check_equal(rs1Data, expectedRsData);
                check_equal(rs2Data, expectedRtData);
            end if;
        end loop;
        wait for 2 ns;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  5 ns);

    forwarding_unit : entity src.riscv32_pipeline_forwarding_unit
    port map (
        rs1DataFromID => rs1DataFromID,
        rs1AddressFromID => rs1AddressFromID,
        rs2DataFromID => rs2DataFromID,
        rs2AddressFromID => rs2AddressFromID,
        regDataFromEx => regDataFromEx,
        regAddressFromEx => regAddressFromEx,
        regWriteFromEx => regWriteFromEx,
        regDataFromMem => regDataFromMem,
        regAddressFromMem => regAddressFromMem,
        regWriteFromMem => regWriteFromMem,
        rs1Data => rs1Data,
        rs2Data => rs2Data
    );
end architecture;
