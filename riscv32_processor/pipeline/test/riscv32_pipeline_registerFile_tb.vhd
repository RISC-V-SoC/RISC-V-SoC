library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg.all;
use src.riscv32_pkg.all;

entity riscv32_pipeline_registerFile_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_pipeline_registerFile_tb is
    constant clk_period : time := 20 ns;

    signal clk : std_logic := '0';
    signal readPortOneAddress : riscv32_registerFileAddress_type := 31;
    signal readPortOneData : riscv32_data_type;

    signal readPortTwoAddress : riscv32_registerFileAddress_type := 31;
    signal readPortTwoData : riscv32_data_type;

    signal writePortDoWrite : boolean := false;
    signal writePortAddress : riscv32_registerFileAddress_type := 31;
    signal writePortData : riscv32_data_type;

    signal extPortAddress : riscv32_registerFileAddress_type := 31;
    signal readPortExtData : riscv32_data_type;
    signal writePortExtDoWrite : boolean := false;
    signal writePortExtData : riscv32_data_type;
begin

    clk <= not clk after (clk_period/2);

    main : process
        variable expectedData : riscv32_data_type := (others => '0');
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            -- Preamble
            writePortDoWrite <= true;
            writePortAddress <= 31;
            writePortData <= (others => '1');
            wait until rising_edge(clk);
            writePortDoWrite <= false;
            wait until rising_edge(clk);
            if run("readPortOne: address zero returns 0") then
                expectedData := (others => '0');
                readPortOneAddress <= 0;
                wait until falling_edge(clk);
                check_equal(readPortOneData, expectedData);
            elsif run("readPortOne: read during relevant write returns writeData") then
                expectedData := X"00112233";
                writePortDoWrite <= true;
                writePortAddress <= 2;
                writePortData <= expectedData;
                readPortOneAddress <= 2;
                wait until falling_edge(clk);
                check_equal(readPortOneData, expectedData);
            elsif run("readPortOne: read during relevant but disabled write returns registerData") then
                expectedData := X"00112233";
                writePortDoWrite <= true;
                writePortAddress <= 2;
                writePortData <= expectedData;
                wait until rising_edge(clk);
                writePortDoWrite <= false;
                writePortAddress <= 2;
                writePortData <= (others => '1');
                readPortOneAddress <= 2;
                wait until falling_edge(clk);
                check_equal(readPortOneData, expectedData);
            elsif run("readPortOne: read during irrelevant write returns registerData") then
                expectedData := X"00112233";
                writePortDoWrite <= true;
                writePortAddress <= 2;
                writePortData <= expectedData;
                wait until rising_edge(clk);
                writePortDoWrite <= true;
                writePortAddress <= 3;
                writePortData <= (others => '1');
                readPortOneAddress <= 2;
                wait until falling_edge(clk);
                check_equal(readPortOneData, expectedData);
            elsif run("writePort: disabled write is ignored") then
                expectedData := X"00112233";
                writePortDoWrite <= true;
                writePortAddress <= 2;
                writePortData <= expectedData;
                wait until rising_edge(clk);
                writePortDoWrite <= false;
                writePortAddress <= 2;
                writePortData <= (others => '1');
                readPortOneAddress <= 2;
                wait until rising_edge(clk);
                check_equal(readPortOneData, expectedData);
            elsif run("ExtPort: Write-then-read works") then
                wait until falling_edge(clk);
                extPortAddress <= 2;
                writePortExtDoWrite <= true;
                writePortExtData <= X"01020304";
                wait until falling_edge(clk);
                check_equal(readPortExtData, writePortExtData);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 us);

    registerFile : entity src.riscv32_pipeline_registerFile
    port map (
        clk => clk,
        readPortOneAddress => readPortOneAddress,
        readPortOneData => readPortOneData,
        readPortTwoAddress => readPortTwoAddress,
        readPortTwoData => readPortTwoData,
        writePortDoWrite => writePortDoWrite,
        writePortAddress => writePortAddress,
        writePortData => writePortData,
        extPortAddress => extPortAddress,
        readPortExtData => readPortExtData,
        writePortExtDoWrite => writePortExtDoWrite,
        writePortExtData => writePortExtData
    );
end architecture;
