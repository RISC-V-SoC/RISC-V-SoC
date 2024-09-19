library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg.all;
use src.riscv32_pkg.all;

entity riscv32_if2bus_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_if2bus_tb is
    constant clk_period : time := 20 ns;
    constant cache_range_start : natural := 16#100000#;
    constant cache_range_end : natural := 16#160000# - 1;
    constant range_to_cache : addr_range_type := (
            low => std_logic_vector(to_unsigned(cache_range_start, bus_address_type'length)),
            high => std_logic_vector(to_unsigned(cache_range_end, bus_address_type'length))
        );
    constant word_count_log2b : natural := 8;

    signal clk : std_logic := '0';
    signal rst : boolean := false;

    signal forbidBusInteraction : boolean := false;
    signal flushCache : boolean := false;

    signal mst2slv : bus_mst2slv_type;
    signal slv2mst : bus_slv2mst_type := BUS_SLV2MST_IDLE;

    signal hasFault : boolean;
    signal faultData : bus_fault_type;
    signal exception_code : riscv32_exception_code_type;

    signal requestAddress : riscv32_address_type := (others => '0');
    signal instruction : riscv32_instruction_type := (others => '0');
    signal stall : boolean;
begin

    clk <= not clk after (clk_period/2);

    main : process
        variable actualAddress : std_logic_vector(bus_address_type'range);
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Requesting instruction stalls bus asap") then
                wait until rising_edge(clk);
                check(stall);
            elsif run("Requesting instruction causes bus request") then
                requestAddress <= X"00100000";
                wait until rising_edge(clk) and bus_requesting(mst2slv);
                check_equal(requestAddress, mst2slv.address);
                check(mst2slv.readReady = '1');
            elsif run("Resolving bus read finishes request") then
                requestAddress <= X"00100000";
                wait until rising_edge(clk) and bus_requesting(mst2slv);
                slv2mst.valid <= true;
                slv2mst.readData <= X"33221100";
                wait until rising_edge(clk) and not stall;
                check_equal(slv2mst.readData, instruction);
            elsif run("Bus fault is acknowledged and communicated") then
                requestAddress <= X"00100000";
                wait until rising_edge(clk) and bus_requesting(mst2slv);
                slv2mst.fault <= '1';
                slv2mst.faultData <= bus_fault_address_out_of_range;
                wait until rising_edge(clk) and any_transaction(mst2slv, slv2mst);
                slv2mst <= BUS_SLV2MST_IDLE;
                wait until rising_edge(clk);
                check(not bus_requesting(mst2slv));
                check(hasFault);
                check_equal(bus_fault_address_out_of_range, faultData);
                check_equal(exception_code, riscv32_exception_code_instruction_access_fault);
            elsif run("Requesting the same address twice does not cause two bus requests") then
                requestAddress <= X"00100000";
                wait until rising_edge(clk) and bus_requesting(mst2slv);
                slv2mst.valid <= true;
                slv2mst.readData <= X"33221100";
                wait until rising_edge(clk) and any_transaction(mst2slv, slv2mst);
                slv2mst <= BUS_SLV2MST_IDLE;
                wait until rising_edge(clk) and not stall;
                check(not any_transaction(mst2slv, slv2mst));
                wait until rising_edge(clk);
                check(not any_transaction(mst2slv, slv2mst));
                wait until rising_edge(clk);
                check(not any_transaction(mst2slv, slv2mst));
            elsif run("Requesting two different addresses does cause two bus requests") then
                requestAddress <= X"00100000";
                wait until rising_edge(clk) and bus_requesting(mst2slv);
                slv2mst.valid <= true;
                slv2mst.readData <= X"33221100";
                wait until rising_edge(clk) and any_transaction(mst2slv, slv2mst);
                wait until rising_edge(clk) and not stall;
                requestAddress <= X"00100004";
                slv2mst <= BUS_SLV2MST_IDLE;
                wait until rising_edge(clk) and bus_requesting(mst2slv);
            elsif run("forbidBusInteraction prevents starting a new interaction but does stall") then
                requestAddress <= X"00100000";
                forbidBusInteraction <= true;
                wait for 5*clk_period;
                check(stall);
                check(not bus_requesting(mst2slv));
            elsif run("forbidBusInteraction during bus request still finishes the request") then
                requestAddress <= X"00100000";
                wait until rising_edge(clk) and bus_requesting(mst2slv);
                forbidBusInteraction <= true;
                wait for 5*clk_period;
                slv2mst.valid <= true;
                slv2mst.readData <= X"33221100";
                wait until rising_edge(clk) and any_transaction(mst2slv, slv2mst);
                slv2mst <= BUS_SLV2MST_IDLE;
                wait until rising_edge(clk) and not stall;
                requestAddress <= X"00100004";
                wait until rising_edge(clk);
                check(stall);
                wait for 5*clk_period;
                check(not bus_requesting(mst2slv));
            elsif run("flushCache flushes the cache") then
                requestAddress <= X"00100000";
                wait until rising_edge(clk) and bus_requesting(mst2slv);
                slv2mst.valid <= true;
                slv2mst.readData <= X"33221100";
                wait until rising_edge(clk) and any_transaction(mst2slv, slv2mst);
                slv2mst <= BUS_SLV2MST_IDLE;
                wait until rising_edge(clk) and not stall;
                flushCache <= true;
                wait until rising_edge(clk);
                flushCache <= false;
                wait until rising_edge(clk);
                check(stall);
                wait until rising_edge(clk) and bus_requesting(mst2slv);
            elsif run("Can cache multiple instructions") then
                requestAddress <= X"00100000";
                wait until rising_edge(clk) and bus_requesting(mst2slv);
                slv2mst.valid <= true;
                slv2mst.readData <= X"01020304";
                wait until rising_edge(clk) and any_transaction(mst2slv, slv2mst);
                slv2mst <= BUS_SLV2MST_IDLE;
                wait until rising_edge(clk) and not stall;
                requestAddress <= X"00100004";
                wait until rising_edge(clk) and bus_requesting(mst2slv);
                slv2mst.valid <= true;
                slv2mst.readData <= X"F1F2F3F4";
                wait until rising_edge(clk) and any_transaction(mst2slv, slv2mst);
                slv2mst <= BUS_SLV2MST_IDLE;
                wait until rising_edge(clk) and not stall;
                requestAddress <= X"00100000";
                wait until rising_edge(clk);
                check(not stall);
                check_equal(instruction, std_logic_vector'(X"01020304"));
            elsif run("Address out of range causes stall") then
                requestAddress <= X"00100000";
                wait until rising_edge(clk) and bus_requesting(mst2slv);
                slv2mst.valid <= true;
                slv2mst.readData <= X"01020304";
                wait until rising_edge(clk) and any_transaction(mst2slv, slv2mst);
                slv2mst <= BUS_SLV2MST_IDLE;
                wait until rising_edge(clk) and not stall;
                requestAddress <= X"00000000";
                wait until rising_edge(clk);
                check(stall);
            elsif run("Address out of cache range causes immidiate stall") then
                requestAddress <= X"00000000";
                wait for 1 fs;
                check(stall);
            elsif run("Address out of range causes fault") then
                requestAddress <= X"00000000";
                wait until rising_edge(clk) and hasFault;
                check_equal(bus_fault_address_out_of_range, faultData);
                check_equal(exception_code, riscv32_exception_code_instruction_access_fault);
            elsif run("After exception we can continue normally") then
                requestAddress <= X"00000000";
                wait until rising_edge(clk) and hasFault;
                wait until rising_edge(clk) and not stall;
                wait for 5*clk_period;
                requestAddress <= X"00100000";
                wait until rising_edge(clk) and bus_requesting(mst2slv);
                check_equal(requestAddress, mst2slv.address);
                check(mst2slv.readReady = '1');
            elsif run("Check unaligned address") then
                requestAddress <= X"00100001";
                wait until rising_edge(clk) and hasFault;
                check_equal(bus_fault_unaligned_access, faultData);
                check_equal(exception_code, riscv32_exception_code_instruction_address_misaligned);
            elsif run("Unaligned address causes stall") then
                requestAddress <= X"00100000";
                wait until rising_edge(clk) and bus_requesting(mst2slv);
                slv2mst.valid <= true;
                slv2mst.readData <= X"33221100";
                wait until rising_edge(clk) and not stall;
                requestAddress <= X"00100001";
                wait for 1 fs;
                check_true(stall);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 us);

    if2bus : entity src.riscv32_if2bus
    generic map (
        range_to_cache => range_to_cache,
        cache_word_count_log2b => word_count_log2b
    ) port map (
        clk => clk,
        rst => rst,
        forbidBusInteraction => forbidBusInteraction,
        flushCache => flushCache,
        mst2slv => mst2slv,
        slv2mst => slv2mst,
        hasFault => hasFault,
        faultData => faultData,
        exception_code => exception_code,
        requestAddress => requestAddress,
        instruction => instruction,
        stall => stall
    );
end architecture;
