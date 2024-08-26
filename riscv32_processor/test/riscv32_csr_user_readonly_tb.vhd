library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.riscv32_pkg.all;

entity riscv32_csr_user_readonly_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_csr_user_readonly_tb is
    signal mst2slv : riscv32_csr_mst2slv_type;
    signal slv2mst : riscv32_csr_slv2mst_type;
    signal address : std_logic_vector(7 downto 0);
    signal read_data : riscv32_data_type;
    signal systemtimer_value : unsigned(63 downto 0);
    signal instructionsRetired_value : unsigned(63 downto 0);
    signal cycleCounter_value : unsigned(63 downto 0);
    signal error : boolean;
begin
    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Address 0 contains cyclecounter") then
                cycleCounter_value <= X"c1a1a1a1b2b2b2c2";
                mst2slv.address <= 0;
                mst2slv.do_read <= true;
                wait for 1 ns;
                check_equal(slv2mst.read_data, std_logic_vector(cycleCounter_value(read_data'range)));
            elsif run("Address 0x80 contains cyclecounter high") then
                cycleCounter_value <= X"c1a1a1a1b2b2b2c2";
                mst2slv.address <= 16#80#;
                mst2slv.do_read <= true;
                wait for 1 ns;
                check_equal(slv2mst.read_data, std_logic_vector(cycleCounter_value(63 downto 32)));
            elsif run("Address 1 contains systemtimer") then
                systemtimer_value <= X"123456789abcdef0";
                mst2slv.address <= 16#1#;
                mst2slv.do_read <= true;
                wait for 1 ns;
                check_equal(slv2mst.read_data, std_logic_vector(systemtimer_value(read_data'range)));
            elsif run("Address 0x82 contains instructionsRetired high") then
                instructionsRetired_value <= X"123456789abcdef0";
                mst2slv.address <= 16#82#;
                mst2slv.do_read <= true;
                wait for 1 ns;
                check_equal(slv2mst.read_data, std_logic_vector(instructionsRetired_value(63 downto 32)));
            elsif run("Address 0x1f gives error") then
                mst2slv.address <= 16#1f#;
                mst2slv.do_read <= true;
                wait for 1 ns;
                check_true(slv2mst.has_error);
            elsif run("Address 0 gives no error") then
                mst2slv.address <= 16#0#;
                mst2slv.do_read <= true;
                wait for 1 ns;
                check_false(slv2mst.has_error);
            end if;
        end loop;
        test_runner_cleanup(runner);
        wait;
    end process;

    csr_user_readonly : entity src.riscv32_csr_user_readonly
    port map (
        cycleCounter_value => cycleCounter_value,
        systemtimer_value => systemtimer_value,
        instructionsRetired_value => instructionsRetired_value,
        mst2slv => mst2slv,
        slv2mst => slv2mst
    );
end architecture;
