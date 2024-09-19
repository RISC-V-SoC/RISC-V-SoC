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
    signal dataOut : riscv32_data_type;
    signal dataIn_forced : riscv32_data_type := (others => '0');
    signal byteMask_forced : riscv32_byte_mask_type := (others => '0');
    signal doWrite_forced : boolean := false;
    signal dataIn_onHit : riscv32_data_type := (others => '0');
    signal byteMask_onHit : riscv32_byte_mask_type := (others => '0');
    signal doWrite_onHit : boolean := false;
    signal miss : boolean;
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
                dataIn_forced <= X"FEDCBA98";
                byteMask_forced <= (others => '1');
                doWrite_forced <= true;
                wait until falling_edge(clk);
                check_equal(dataOut, dataIn_forced);
                check(not miss);
            elsif run("Can miss") then
                addressIn <= X"01020304";
                wait for 1 fs;
                check(miss);
            elsif run("Update single byte") then
                wait until falling_edge(clk);
                addressIn <= X"01020304";
                dataIn_forced <= X"FEDCBA98";
                byteMask_forced <= (others => '1');
                doWrite_forced <= true;
                wait until falling_edge(clk);
                dataIn_forced <= X"000000FF";
                byteMask_forced <= X"1";
                wait until falling_edge(clk);
                check_equal(dataOut, std_logic_vector'(X"FEDCBAFF"));
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
        dataOut => dataOut,
        dataIn_forced => dataIn_forced,
        byteMask_forced => byteMask_forced,
        doWrite_forced => doWrite_forced,
        dataIn_onHit => dataIn_onHit,
        byteMask_onHit => byteMask_onHit,
        doWrite_onHit => doWrite_onHit,
        miss => miss
    );


end architecture;
