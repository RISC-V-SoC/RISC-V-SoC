library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg.all;
use src.riscv32_pkg.all;

library tb;
use tb.riscv32_instruction_builder_pkg.all;

entity riscv32_pipeline_programCounter_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_pipeline_programCounter_tb is
    constant clk_period : time := 20 ns;
    constant startAddress : natural := 16#00000014#;

    signal clk : std_logic := '0';
    signal rst : boolean := false;
    signal stall : boolean := false;
    signal enable : boolean := true;

    signal requestFromBusAddress : riscv32_address_type;
    signal requestFromBusEnable : boolean;

    signal overrideProgramCounterFromID : boolean := false;
    signal newProgramCounterFromID : riscv32_instruction_type := (others => '1');

    signal overrideProgramCounterFromEx : boolean := false;
    signal newProgramCounterFromEx : riscv32_instruction_type := (others => '1');

    signal overrideProgramCounterFromInterrupt : boolean := false;
    signal newProgramCounterFromInterrupt : riscv32_instruction_type := (others => '1');
begin
    clk <= not clk after (clk_period/2);

    main : process
        variable expectedAddress : riscv32_address_type;
        variable expectedInstruction : riscv32_instruction_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("On start, the requested address should be the reset address") then
                check_equal(to_integer(unsigned(requestFromBusAddress)), startAddress);
            elsif run("On start, the request to the bus controller should be enabled") then
                check_true(requestFromBusEnable);
            elsif run("When enabled, the program counter adds four on a rising edge") then
                expectedAddress := std_logic_vector(to_unsigned(startAddress + 4, expectedAddress'length));
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(requestFromBusAddress, expectedAddress);
            elsif run("When disabled, the request to the bus controller should be disabled") then
                enable <= false;
                wait for 1 fs;
                check_false(requestFromBusEnable);
            elsif run("When disabled, the program counter should not change") then
                enable <= false;
                expectedAddress := requestFromBusAddress;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(requestFromBusAddress, expectedAddress);
            elsif run("When stalled, the program counter should not change") then
                stall <= true;
                expectedAddress := requestFromBusAddress;
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(requestFromBusAddress, expectedAddress);
            elsif run("rst sets the program counter to the reset address") then
                wait until rising_edge(clk);
                rst <= true;
                wait until rising_edge(clk);
                rst <= false;
                wait until falling_edge(clk);
                check_equal(to_integer(unsigned(requestFromBusAddress)), startAddress);
            elsif run("Override program counter from ID") then
                overrideProgramCounterFromID <= true;
                newProgramCounterFromID <= std_logic_vector(to_unsigned(startAddress + 8, newProgramCounterFromID'length));
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(requestFromBusAddress, newProgramCounterFromID);
            elsif run("Override program counter from EX") then
                overrideProgramCounterFromEx <= true;
                newProgramCounterFromEx <= std_logic_vector(to_unsigned(startAddress + 12, newProgramCounterFromEx'length));
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(requestFromBusAddress, newProgramCounterFromEx);
            elsif run("Override program counter from interrupt") then
                overrideProgramCounterFromInterrupt <= true;
                newProgramCounterFromInterrupt <= std_logic_vector(to_unsigned(startAddress + 16, newProgramCounterFromInterrupt'length));
                wait until rising_edge(clk);
                wait until falling_edge(clk);
                check_equal(requestFromBusAddress, newProgramCounterFromInterrupt);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 us);

    programCounter : entity src.riscv32_pipeline_programCounter
    generic map (
        startAddress => std_logic_vector(to_unsigned(startAddress, riscv32_address_type'length))
    ) port map (
        clk => clk,
        rst => rst,
        enable => enable,
        stall => stall,
        requestFromBusAddress => requestFromBusAddress,
        requestFromBusEnable => requestFromBusEnable,
        overrideProgramCounterFromID => overrideProgramCounterFromID,
        newProgramCounterFromID => newProgramCounterFromID,
        overrideProgramCounterFromEx => overrideProgramCounterFromEx,
        newProgramCounterFromEx => newProgramCounterFromEx,
        overrideProgramCounterFromInterrupt => overrideProgramCounterFromInterrupt,
        newProgramCounterFromInterrupt => newProgramCounterFromInterrupt
    );
end architecture;
