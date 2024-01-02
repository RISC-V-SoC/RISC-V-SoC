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
    signal dataOut : riscv32_data_type;
    signal dataIn : riscv32_data_type := (others => '0');
    signal tagOut : std_logic_vector(tag_size - 1 downto 0);
    signal tagIn : std_logic_vector(tag_size - 1 downto 0) := (others => '0');
    signal byteMask : riscv32_byte_mask_type := (others => '0');
    signal valid : boolean;
    signal dirty : boolean;
    signal resetDirty : boolean;
    signal doWrite : boolean := false;
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
                doWrite <= true;
                requestAddress <= X"04";
                dataIn <= X"01020304";
                tagIn <= X"6";
                byteMask <= (others => '1');
                wait until falling_edge(clk);
                check_equal(dataOut, dataIn);
                check_equal(tagOut, tagIn);
            elsif run("After a write, valid becomes high") then
                wait until falling_edge(clk);
                doWrite <= true;
                requestAddress <= X"04";
                dataIn <= X"01020304";
                tagIn <= X"6";
                byteMask <= (others => '1');
                wait until falling_edge(clk);
                check(valid);
            elsif run("Before the first write, valid is false") then
                check(not valid);
            elsif run("Bytemask can create partial write") then
                wait until falling_edge(clk);
                doWrite <= true;
                requestAddress <= X"04";
                dataIn <= X"01020304";
                tagIn <= X"6";
                byteMask <= (others => '1');
                wait until falling_edge(clk);
                dataIn <= X"FFFFFFFF";
                byteMask <= "1100";
                wait until falling_edge(clk);
                check_equal(dataOut, std_logic_vector'(X"FFFF0304"));
            elsif run("Without doWrite, dont write") then
                wait until falling_edge(clk);
                doWrite <= true;
                requestAddress <= X"04";
                dataIn <= X"01020304";
                tagIn <= X"6";
                byteMask <= (others => '1');
                wait until falling_edge(clk);
                doWrite <= false;
                dataIn <= X"FFFFFFFF";
                tagIn <= X"5";
                wait until falling_edge(clk);
                check_equal(dataOut, std_logic_vector'(X"01020304"));
                check_equal(tagOut, std_logic_vector'(X"6"));
            elsif run("Without doWrite, valid remains false") then
                wait until falling_edge(clk);
                requestAddress <= X"04";
                dataIn <= X"01020304";
                tagIn <= X"6";
                byteMask <= (others => '1');
                wait until falling_edge(clk);
                check(not valid);
            elsif run("On a non-dirty-resetting write, dirty becomes true") then
                wait until falling_edge(clk);
                doWrite <= true;
                requestAddress <= X"04";
                dataIn <= X"01020304";
                tagIn <= X"6";
                byteMask <= (others => '1');
                wait until falling_edge(clk);
                check(dirty);
            elsif run("On a dirty-resetting write, dirty ends up false") then
                wait until falling_edge(clk);
                doWrite <= true;
                requestAddress <= X"04";
                dataIn <= X"01020304";
                tagIn <= X"6";
                byteMask <= (others => '1');
                resetDirty <= true;
                wait until falling_edge(clk);
                check(not dirty);
            elsif run("On a non-write, dirty remains unchanged") then
                wait until falling_edge(clk);
                doWrite <= true;
                requestAddress <= X"04";
                dataIn <= X"01020304";
                tagIn <= X"6";
                byteMask <= (others => '1');
                resetDirty <= true;
                wait until falling_edge(clk);
                doWrite <= false;
                resetDirty <= false;
                wait until falling_edge(clk);
                check(not dirty);
            elsif run("Can store two words") then
                wait until falling_edge(clk);
                doWrite <= true;
                requestAddress <= X"04";
                dataIn <= X"01020304";
                tagIn <= X"6";
                byteMask <= (others => '1');
                wait until falling_edge(clk);
                doWrite <= true;
                requestAddress <= X"08";
                dataIn <= X"F1F2F3F4";
                tagIn <= X"7";
                byteMask <= (others => '1');
                wait until falling_edge(clk);
                requestAddress <= X"04";
                doWrite <= false;
                wait for 1 fs;
                check_equal(dataOut, std_logic_vector'(X"01020304"));
                check_equal(tagOut, std_logic_vector'(X"6"));
            elsif run("reset resets valid") then
                wait until falling_edge(clk);
                doWrite <= true;
                requestAddress <= X"04";
                dataIn <= X"01020304";
                tagIn <= X"6";
                byteMask <= (others => '1');
                resetDirty <= true;
                wait until falling_edge(clk);
                doWrite <= false;
                rst <= '1';
                wait until falling_edge(clk);
                check(not valid);
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
        dataOut => dataOut,
        dataIn => dataIn,
        tagOut => tagOut,
        tagIn => tagIn,
        byteMask => byteMask,
        valid => valid,
        dirty => dirty,
        resetDirty => resetDirty,
        doWrite => doWrite
    );

end architecture;
