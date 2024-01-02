library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg.all;
use src.riscv32_pkg.all;

entity riscv32_dcache_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_dcache_tb is
    constant clk_period : time := 20 ns;
    constant word_count_log2b : natural := 8;
    constant tag_size : natural := 22;

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';

    signal addressIn : riscv32_address_type := (others => '0');
    signal addressOut : riscv32_address_type;
    signal dataIn : riscv32_data_type := (others => '0');
    signal dataOut : riscv32_data_type;
    signal byteMask : riscv32_byte_mask_type := (others => '0');
    signal doWrite : boolean := false;
    signal miss : boolean;
    signal resetDirty : boolean := false;
    signal dirty : boolean;
begin

    clk <= not clk after (clk_period/2);

    main : process
        variable actualAddress : std_logic_vector(bus_address_type'range);
        variable writeValue : riscv32_data_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Store some data and read it back") then
                wait until falling_edge(clk);
                addressIn <= X"01020304";
                dataIn <= X"FEDCBA98";
                byteMask <= (others => '1');
                doWrite <= true;
                resetDirty <= true;
                wait until falling_edge(clk);
                check_equal(addressOut, addressIn);
                check_equal(dataOut, dataIn);
                check(not dirty);
                check(not miss);
            elsif run("Can miss") then
                addressIn <= X"01020304";
                wait for 1 fs;
                check(miss);
            elsif run("Update single byte") then
                wait until falling_edge(clk);
                addressIn <= X"01020304";
                dataIn <= X"FEDCBA98";
                byteMask <= (others => '1');
                doWrite <= true;
                resetDirty <= true;
                wait until falling_edge(clk);
                dataIn <= X"000000FF";
                byteMask <= X"1";
                wait until falling_edge(clk);
                check_equal(dataOut, std_logic_vector'(X"FEDCBAFF"));
            elsif run("Miss but dirty outputs data and address of dirty cache line") then
                wait until falling_edge(clk);
                addressIn <= X"00000000";
                dataIn <= X"22222222";
                byteMask <= (others => '1');
                doWrite <= true;
                resetDirty <= false;
                wait until falling_edge(clk);
                addressIn <= X"00000400";
                dataIn <= X"33333333";
                wait for 1 fs;
                check(miss);
                check(dirty);
                check_equal(addressOut, std_logic_vector'(X"00000000"));
                check_equal(dataOut, std_logic_vector'(X"22222222"));
            elsif run("Invalid cache lines cannot be dirty") then
                wait until falling_edge(clk);
                addressIn <= X"00000000";
                dataIn <= X"22222222";
                byteMask <= (others => '1');
                doWrite <= true;
                resetDirty <= false;
                wait until falling_edge(clk);
                doWrite <= false;
                rst <= '1';
                wait until falling_edge(clk);
                rst <= '0';
                check(not dirty);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;
    test_runner_watchdog(runner,  100 ns);

    dcache : entity src.riscv32_dcache
    generic map (
        word_count_log2b => word_count_log2b,
        tag_size => tag_size
    ) port map (
        clk => clk,
        rst => rst,
        addressIn => addressIn,
        addressOut => addressOut,
        dataIn => dataIn,
        dataOut => dataOut,
        byteMask => byteMask,
        doWrite => doWrite,
        miss => miss,
        resetDirty => resetDirty,
        dirty => dirty
    );


end architecture;
