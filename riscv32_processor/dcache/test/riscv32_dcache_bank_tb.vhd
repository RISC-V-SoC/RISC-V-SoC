library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg.all;
use src.riscv32_pkg.all;

entity riscv32_dcache_bank_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_dcache_bank_tb is
    constant clk_period : time := 20 ns;
    constant word_count_log2b : natural := 8;
    constant tag_size : natural := 4;

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';

    signal requestAddress : std_logic_vector(word_count_log2b - 1 downto 0) := (others => '0');
    signal tagIn : std_logic_vector(tag_size - 1 downto 0) := (others => '0');

    signal dataIn_forced : riscv32_data_type := (others => '0');
    signal doWrite_forced : boolean := false;
    signal byteMask_forced : riscv32_byte_mask_type := (others => '0');

    signal dataIn_onHit : riscv32_data_type := (others => '0');
    signal doWrite_onHit : boolean := false;
    signal byteMask_onHit : riscv32_byte_mask_type := (others => '0');

    signal dataOut : riscv32_data_type;
    signal hit : boolean;
begin

    clk <= not clk after (clk_period/2);

    main : process
        variable actualAddress : std_logic_vector(bus_address_type'range);
        variable writeValue : riscv32_data_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Write then read works") then
                wait until falling_edge(clk);
                doWrite_forced <= true;
                requestAddress <= X"04";
                dataIn_forced <= X"01020304";
                tagIn <= X"6";
                byteMask_forced <= (others => '1');
                wait until falling_edge(clk);
                check_equal(dataOut, dataIn_forced);
                check_true(hit);
            elsif run("After a write, hit becomes high") then
                wait until falling_edge(clk);
                doWrite_forced <= true;
                requestAddress <= X"04";
                dataIn_forced <= X"01020304";
                tagIn <= X"6";
                byteMask_forced <= (others => '1');
                wait until falling_edge(clk);
                check_true(hit);
            elsif run("Before the first write, hit is false") then
                check(not hit);
            elsif run("Bytemask can create partial write") then
                wait until falling_edge(clk);
                doWrite_forced <= true;
                requestAddress <= X"04";
                dataIn_forced <= X"01020304";
                tagIn <= X"6";
                byteMask_forced <= (others => '1');
                wait until falling_edge(clk);
                dataIn_forced <= X"FFFFFFFF";
                byteMask_forced <= "1100";
                wait until falling_edge(clk);
                check_equal(dataOut, std_logic_vector'(X"FFFF0304"));
            elsif run("Without doWrite_forced, dont write") then
                wait until falling_edge(clk);
                doWrite_forced <= true;
                requestAddress <= X"04";
                dataIn_forced <= X"01020304";
                tagIn <= X"6";
                byteMask_forced <= (others => '1');
                wait until falling_edge(clk);
                doWrite_forced <= false;
                dataIn_forced <= X"FFFFFFFF";
                tagIn <= X"5";
                wait until falling_edge(clk);
                check_equal(dataOut, std_logic_vector'(X"01020304"));
                check_false(hit);
            elsif run("Without doWrite_forced, hit remains false") then
                wait until falling_edge(clk);
                requestAddress <= X"04";
                dataIn_forced <= X"01020304";
                tagIn <= X"6";
                byteMask_forced <= (others => '1');
                wait until falling_edge(clk);
                check(not hit);
            elsif run("Can store two words") then
                wait until falling_edge(clk);
                doWrite_forced <= true;
                requestAddress <= X"04";
                dataIn_forced <= X"01020304";
                tagIn <= X"6";
                byteMask_forced <= (others => '1');
                wait until falling_edge(clk);
                doWrite_forced <= true;
                requestAddress <= X"08";
                dataIn_forced <= X"F1F2F3F4";
                tagIn <= X"7";
                byteMask_forced <= (others => '1');
                wait until falling_edge(clk);
                requestAddress <= X"04";
                tagIn <= X"6";
                doWrite_forced <= false;
                wait for 1 fs;
                check_equal(dataOut, std_logic_vector'(X"01020304"));
                check_true(hit);
            elsif run("reset resets a cacheline") then
                wait until falling_edge(clk);
                doWrite_forced <= true;
                requestAddress <= X"04";
                dataIn_forced <= X"01020304";
                tagIn <= X"6";
                byteMask_forced <= (others => '1');
                wait until falling_edge(clk);
                doWrite_forced <= false;
                rst <= '1';
                wait until falling_edge(clk);
                check(not hit);
            elsif run("write_onHit writes on hit") then
                wait until falling_edge(clk);
                doWrite_forced <= true;
                requestAddress <= X"04";
                dataIn_forced <= X"01020304";
                tagIn <= X"6";
                byteMask_forced <= (others => '1');
                wait until falling_edge(clk);
                doWrite_forced <= false;
                doWrite_onHit <= true;
                dataIn_onHit <= X"F1F2F3F4";
                bytemask_onHit <= (others => '1');
                wait until falling_edge(clk);
                check_equal(dataOut, dataIn_onHit);
                check_true(hit);
            elsif run("write_onHit does not write on miss") then
                wait until falling_edge(clk);
                doWrite_forced <= true;
                requestAddress <= X"04";
                dataIn_forced <= X"01020304";
                tagIn <= X"6";
                byteMask_forced <= (others => '1');
                wait until falling_edge(clk);
                doWrite_forced <= false;
                doWrite_onHit <= true;
                dataIn_onHit <= X"F1F2F3F4";
                bytemask_onHit <= (others => '1');
                tagIn <= X"4";
                wait until falling_edge(clk);
                check_equal(dataOut, dataIn_forced);
                check_false(hit);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;
    test_runner_watchdog(runner,  100 ns);

    dcache_bank : entity src.riscv32_dcache_bank
    generic map (
        word_count_log2b => word_count_log2b,
        tag_size => tag_size
    ) port map (
        clk => clk,
        rst => rst,
        requestAddress => requestAddress,
        tagIn => tagIn,
        dataIn_forced => dataIn_forced,
        doWrite_forced => doWrite_forced,
        byteMask_forced => byteMask_forced,
        dataIn_onHit => dataIn_onHit,
        doWrite_onHit => doWrite_onHit,
        byteMask_onHit => byteMask_onHit,
        dataOut => dataOut,
        hit => hit
    );

end architecture;
