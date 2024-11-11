library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg.all;
use src.riscv32_pkg.all;

entity riscv32_write_back_dcache_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_write_back_dcache_tb is
    constant clk_period : time := 20 ns;
    constant word_count_log2b : natural := 4;
    constant cache_range_size : natural := 16#10000#;
    constant cached_base_address : bus_address_type := X"00020000";

    signal clk : std_logic := '0';
    signal rst : boolean := false;

    signal addressIn : bus_aligned_address_type;

    signal proc_dataIn : riscv32_data_type;
    signal proc_byteMask : riscv32_byte_mask_type;
    signal proc_doWrite : boolean;

    signal bus_dataIn : bus_data_type;
    signal bus_doWrite : boolean;

    signal dataOut : riscv32_data_type;
    signal reconstructedAddr : bus_aligned_address_type;
    signal dirty : boolean;
    signal miss : boolean;
begin

    clk <= not clk after (clk_period/2);

    main : process
        variable fullAddress : bus_address_type;
        variable actualAddress : std_logic_vector(bus_address_type'range);
        variable writeValue : riscv32_data_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Store two words via bus channel and read them back") then
                wait until falling_edge(clk);
                addressIn <= std_logic_vector(to_unsigned(0, addressIn'length));
                bus_dataIn <= X"12345678";
                bus_doWrite <= true;
                wait until falling_edge(clk);
                addressIn <= std_logic_vector(to_unsigned(1, addressIn'length));
                bus_dataIn <= X"87654321";
                bus_doWrite <= true;
                wait until falling_edge(clk);
                addressIn <= std_logic_vector(to_unsigned(0, addressIn'length));
                bus_doWrite <= false;
                wait for 1 fs;
                check_equal(dataOut, std_logic_vector'(X"12345678"));
            elsif run("Can miss") then
                wait until falling_edge(clk);
                addressIn <= std_logic_vector(to_unsigned(0, addressIn'length));
                bus_dataIn <= X"12345678";
                bus_doWrite <= true;
                wait until falling_edge(clk);
                addressIn <= std_logic_vector(to_unsigned(16, addressIn'length));
                bus_doWrite <= false;
                wait for 1 fs;
                check_true(miss);
            elsif run("Can hit") then
                wait until falling_edge(clk);
                addressIn <= std_logic_vector(to_unsigned(0, addressIn'length));
                bus_dataIn <= X"12345678";
                bus_doWrite <= true;
                wait until falling_edge(clk);
                bus_doWrite <= false;
                check_false(miss);
            elsif run("Write from proc also cause hit on re-read") then
                addressIn <= std_logic_vector(to_unsigned(0, addressIn'length));
                proc_dataIn <= X"12345678";
                proc_byteMask <= "1111";
                proc_doWrite <= true;
                wait until falling_edge(clk);
                proc_doWrite <= false;
                check_false(miss);
            elsif run("Supports partial update from proc") then
                wait until falling_edge(clk);
                addressIn <= std_logic_vector(to_unsigned(0, addressIn'length));
                bus_dataIn <= X"12345678";
                bus_doWrite <= true;
                wait until falling_edge(clk);
                bus_doWrite <= false;
                proc_dataIn <= X"FF00FF00";
                proc_byteMask <= "1010";
                proc_doWrite <= true;
                wait until falling_edge(clk);
                proc_doWrite <= false;
                check_equal(dataOut, std_logic_vector'(X"FF34FF78"));
            elsif run("Invalid line must miss") then
                addressIn <= std_logic_vector(to_unsigned(16#0#, addressIn'length));
                wait for 1 fs;
                check_true(miss);
            elsif run("A write from proc must make the line dirty") then
                wait until falling_edge(clk);
                addressIn <= std_logic_vector(to_unsigned(16#0#, addressIn'length));
                proc_dataIn <= X"FF00FF00";
                proc_byteMask <= "1111";
                proc_doWrite <= true;
                wait until falling_edge(clk);
                proc_doWrite <= false;
                check_true(dirty);
            elsif run("Invalid line is not dirty") then
                addressIn <= std_logic_vector(to_unsigned(16#0#, addressIn'length));
                wait for 1 fs;
                check_false(dirty);
            elsif run("A write from bus resets dirty") then
                wait until falling_edge(clk);
                addressIn <= std_logic_vector(to_unsigned(16#0#, addressIn'length));
                proc_dataIn <= X"FF00FF00";
                proc_byteMask <= "1111";
                proc_doWrite <= true;
                wait until falling_edge(clk);
                proc_doWrite <= false;
                bus_dataIn <= X"12345678";
                bus_doWrite <= true;
                wait until falling_edge(clk);
                bus_doWrite <= false;
                check_false(dirty);
            elsif run("Reset turns hit into miss") then
                addressIn <= std_logic_vector(to_unsigned(0, addressIn'length));
                proc_dataIn <= X"12345678";
                proc_byteMask <= "1111";
                proc_doWrite <= true;
                wait until falling_edge(clk);
                proc_doWrite <= false;
                rst <= true;
                wait until falling_edge(clk);
                rst <= false;
                check_true(miss);
            elsif run("Reset resets dirty") then
                addressIn <= std_logic_vector(to_unsigned(0, addressIn'length));
                proc_dataIn <= X"12345678";
                proc_byteMask <= "1111";
                proc_doWrite <= true;
                wait until falling_edge(clk);
                proc_doWrite <= false;
                rst <= true;
                wait until falling_edge(clk);
                rst <= false;
                check_false(dirty);
            elsif run("Address can be reconstructed") then
                fullAddress := std_logic_vector(to_unsigned(16#2100C#, fullAddress'length));
                addressIn <= fullAddress(addressIn'range);
                proc_dataIn <= X"12345678";
                proc_byteMask <= "1111";
                proc_doWrite <= true;
                wait until falling_edge(clk);
                fullAddress := std_logic_vector(to_unsigned(16#2200C#, fullAddress'length));
                addressIn <= fullAddress(addressIn'range);
                proc_doWrite <= false;
                wait for 1 fs;
                fullAddress := std_logic_vector(to_unsigned(16#2100C#, fullAddress'length));
                check_equal(reconstructedAddr, fullAddress(reconstructedAddr'range));
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;
    test_runner_watchdog(runner,  100 ns);

    dcache : entity src.riscv32_write_back_dcache
    generic map (
        word_count_log2b => word_count_log2b,
        cache_range_size => cache_range_size,
        cached_base_address => cached_base_address(bus_aligned_address_type'range)
    ) port map (
        clk => clk,
        rst => rst,
        addressIn => addressIn,
        proc_dataIn => proc_dataIn,
        proc_byteMask => proc_byteMask,
        proc_doWrite => proc_doWrite,
        bus_dataIn => bus_dataIn,
        bus_doWrite => bus_doWrite,
        dataOut => dataOut,
        reconstructedAddr => reconstructedAddr,
        dirty => dirty,
        miss => miss
    );


end architecture;
