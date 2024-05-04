library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
library tb;
use src.bus_pkg;
use src.triple_23lc1024_pkg.all;

entity triple_23LC1024_bus_parser_tb is
    generic (runner_cfg : string);
end entity;

architecture tb of triple_23LC1024_bus_parser_tb is
    constant clk_period : time := 20 ns;
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';

    signal mst2slv : bus_pkg.bus_mst2slv_type := bus_pkg.BUS_MST2SLV_IDLE;
    signal transaction_valid : boolean := false;

    signal request_length : positive range 1 to bus_pkg.bus_bytes_per_word;

    signal cs_request : cs_request_type;
    signal fault_data : bus_pkg.bus_fault_type;
    signal write_data : bus_pkg.bus_data_type;
    signal address : bus_pkg.bus_address_type;

    signal has_fault : boolean;
    signal read_request : boolean;
    signal write_request : boolean;
    signal virtual_write_burst : boolean;
    signal any_active : boolean := false;
begin
    clk <= not clk after (clk_period/2);
    process
        variable expected_start_address : std_logic_vector(16 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Decodes cs_request for zero") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00001100");
                wait until rising_edge(clk) and read_request;
                check(cs_request = request_zero);
            elsif run("Decodes cs_request for one") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00021100");
                wait until rising_edge(clk) and read_request;
                check(cs_request = request_one);
            elsif run("Has no active read request on IDLE") then
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                check(not read_request);
                wait for 5*clk_period;
                check(read_request'stable(5*clk_period));
            elsif run("Deactivates read on transaction") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00021100");
                wait until rising_edge(clk) and read_request;
                transaction_valid <= true;
                wait until falling_edge(clk);
                wait for clk_period;
                check(not read_request);
            elsif run("Forwards write request") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00021100", X"0f0f0f0f");
                wait until rising_edge(clk) and write_request;
            elsif run("Has no active write request on IDLE") then
                mst2slv <= bus_pkg.BUS_MST2SLV_IDLE;
                check(not write_request);
                wait for 5*clk_period;
                check(write_request'stable(5*clk_period));
            elsif run("Deactivates write on transaction") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00021100", X"0f0f0f0f");
                wait for clk_period;
                check(write_request);
                transaction_valid <= true;
                wait for clk_period;
                check(not write_request);
            elsif run("Faults on address out of range") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"fffffff0");
                wait until rising_edge(clk) and has_fault;
                check(fault_data = bus_pkg.bus_fault_address_out_of_range);
            elsif run("Does not fault on address in range") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00021100");
                wait until rising_edge(clk) and read_request;
            elsif run("On fault, read_request is false") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"ffffffff");
                wait until rising_edge(clk) and has_fault;
                check(not read_request);
            elsif run("On fault, write_request is false") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"ffffffff", X"0f0f0f0f");
                wait until rising_edge(clk) and has_fault;
                check(not write_request);
            elsif run("Fault transaction can finish") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"ffffffff");
                wait until rising_edge(clk) and has_fault;
                wait for clk_period;
                check(not has_fault);
            elsif run("0000 is an illegal byte mask") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00021100", byte_mask => "0000");
                wait until rising_edge(clk) and has_fault;
                check(fault_data = bus_pkg.bus_fault_illegal_byte_mask);
            elsif run("byte mask 1111 requires a 4 byte alignment") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00021102", byte_mask => "1111");
                wait until rising_edge(clk) and has_fault;
                check(fault_data = bus_pkg.bus_fault_unaligned_access);
            elsif run("byte mask 0011 requires a 2 byte alignment") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00021102", byte_mask => "0011");
                wait until rising_edge(clk) and read_request;
            elsif run("Unaligned address and byte mask 0100 is illegal") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"0002110f", byte_mask => "0100");
                wait until rising_edge(clk) and has_fault;
                check(fault_data = bus_pkg.bus_fault_illegal_byte_mask);
            elsif run("Byte mask 0001 allows any alignment") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"0002110f", byte_mask => "0001");
                wait until rising_edge(clk) and read_request;
            elsif run("byte mask 1111 results in request length of 4") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00021100", byte_mask => "1111");
                wait until rising_edge(clk) and read_request;
                check_equal(request_length, 4);
            elsif run("byte mask 0011 results in request length of 2") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00021100", byte_mask => "0011");
                wait until rising_edge(clk) and read_request;
                check_equal(request_length, 2);
            elsif run("No request means no fault") then
                mst2slv.byteMask <= "0000";
                check(not has_fault);
                wait for 5*clk_period;
                check(has_fault'stable(5*clk_period));
            elsif run("Rst works") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00021100", byte_mask => "0011");
                wait for clk_period;
                check(read_request);
                rst <= '1';
                wait for clk_period;
                check(not read_request);
            elsif run("After a fault, the parser has to wait for all units to finish") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"0002110f", byte_mask => "0100");
                any_active <= true;
                wait until rising_edge(clk) and has_fault;
                wait until rising_edge(clk);
                wait for clk_period/2;
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00021100", byte_mask => "1111");
                wait for clk_period;
                check(not read_request);
                any_active <= false;
                wait for clk_period;
                wait for clk_period;
                check(read_request);
            elsif run("A burst operation where the next operation would cross a segment line is illegal") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"0001fffc", burst => '1');
                wait until rising_edge(clk) and has_fault;
                check(fault_data = bus_pkg.bus_fault_illegal_address_for_burst);
            elsif run("Aligned read with bytemask 0110 leads to size 4 read") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00021100", byte_mask => "0110");
                wait until rising_edge(clk) and read_request;
                check_equal(request_length, 4);
            elsif run("Aligned write with bytemask 0110 leads to size 2 write, address and data modified") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00021100", X"01234567", "0110");
                wait until rising_edge(clk) and write_request;
                check_equal(request_length, 2);
                check_equal(address, std_logic_vector'(X"00021101"));
                check_equal(write_data, std_logic_vector'(X"00012345"));
            elsif run("Bytemask with holes is illegal") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00021100", byte_mask => "0101");
                wait until rising_edge(clk) and has_fault;
                check(fault_data = bus_pkg.bus_fault_illegal_byte_mask);
            elsif run("Two sequential writes cause a virtual burst") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000000", X"0f0f0f0f");
                wait until rising_edge(clk) and write_request;
                transaction_valid <= true;
                wait until rising_edge(clk) and not write_request;
                transaction_valid <= false;
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000004", X"0f0f0f0f");
                wait until rising_edge(clk) and write_request;
                check(virtual_write_burst);
            elsif run("Write after read with sequential address does not cause a virtual burst") then
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000000");
                wait until rising_edge(clk) and read_request;
                transaction_valid <= true;
                wait until rising_edge(clk) and not read_request;
                transaction_valid <= false;
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000004", X"0f0f0f0f");
                wait until rising_edge(clk) and write_request;
                check(not virtual_write_burst);
            elsif run("Non-sequential writes do not cause a virtual burst") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000000", X"0f0f0f0f");
                wait until rising_edge(clk) and write_request;
                transaction_valid <= true;
                wait until rising_edge(clk) and not write_request;
                transaction_valid <= false;
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000008", X"0f0f0f0f");
                wait until rising_edge(clk) and write_request;
                check(not virtual_write_burst);
            elsif run("No write request means no virtual burst") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000000", X"0f0f0f0f");
                wait until rising_edge(clk) and write_request;
                transaction_valid <= true;
                wait until rising_edge(clk) and not write_request;
                transaction_valid <= false;
                mst2slv <= bus_pkg.bus_mst2slv_read(X"00000004");
                wait until rising_edge(clk) and read_request;
                check(not virtual_write_burst);
            elsif run("No virtual burst if lengths differ") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000000", X"0f0f0f0f");
                wait until rising_edge(clk) and write_request;
                transaction_valid <= true;
                wait until rising_edge(clk) and not write_request;
                transaction_valid <= false;
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000004", X"0f0f0f0f", "0011");
                wait until rising_edge(clk) and write_request;
                check(not virtual_write_burst);
            elsif run("Virtual burst checks effective address") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000000", X"0f0f0f0f", "0001");
                wait until rising_edge(clk) and write_request;
                transaction_valid <= true;
                wait until rising_edge(clk) and not write_request;
                transaction_valid <= false;
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00000000", X"0f0f0f0f", "0010");
                wait until rising_edge(clk) and write_request;
                check(virtual_write_burst);
            elsif run("No virtual burst on segment crossing") then
                mst2slv <= bus_pkg.bus_mst2slv_write(X"0001fffc", X"0f0f0f0f");
                wait until rising_edge(clk) and write_request;
                transaction_valid <= true;
                wait until rising_edge(clk) and not write_request;
                transaction_valid <= false;
                mst2slv <= bus_pkg.bus_mst2slv_write(X"00020000", X"0f0f0f0f");
                wait until rising_edge(clk) and write_request;
                check(not virtual_write_burst);
            end if;
        end loop;
        wait for 2*clk_period;
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 10 us);

    parser : entity src.triple_23lc1024_bus_parser
    port map (
        clk => clk,
        rst => rst,
        mst2slv => mst2slv,
        transaction_valid => transaction_valid,
        any_active => any_active,
        request_length => request_length,
        cs_request => cs_request,
        fault_data => fault_data,
        write_data => write_data,
        address => address,
        has_fault => has_fault,
        read_request => read_request,
        write_request => write_request,
        virtual_write_burst => virtual_write_burst
    );
end architecture;
