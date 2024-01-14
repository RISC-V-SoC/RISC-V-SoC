library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.riscv32_pkg.all;

entity riscv32_csr_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_csr_tb is
    signal csr_in : riscv32_to_csr_type;
    signal read_data : riscv32_data_type;
    signal systemtimer_value : unsigned(63 downto 0);
    signal instructionsRetired_value : unsigned(63 downto 0);
    signal error : boolean;
begin
    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Read request from address 0x7B0 should cause error") then
                csr_in.command <= csr_rw;
                csr_in.address <= X"7b0";
                csr_in.data_in <= (others => '0');
                csr_in.do_write <= false;
                csr_in.do_read <= true;
                wait for 1 ns;
                check(error);
            elsif run("No request means no error") then
                csr_in.command <= csr_rw;
                csr_in.address <= X"7b0";
                csr_in.data_in <= (others => '0');
                csr_in.do_write <= false;
                csr_in.do_read <= false;
                wait for 1 ns;
                check(not error);
            elsif run("Write request to address 0x7B0 should cause error") then
                csr_in.command <= csr_rw;
                csr_in.address <= X"7b0";
                csr_in.data_in <= (others => '0');
                csr_in.do_write <= true;
                csr_in.do_read <= false;
                wait for 1 ns;
                check(error);
            elsif run("Read request from 0xC01 returns lower 32 bit of system time") then
                systemtimer_value <= X"a1a1a1a1b2b2b2b2";
                csr_in.command <= csr_rw;
                csr_in.address <= X"C01";
                csr_in.data_in <= (others => '0');
                csr_in.do_write <= false;
                csr_in.do_read <= true;
                wait for 1 ns;
                check(not error);
                check_equal(unsigned(read_data), systemtimer_value(31 downto 0));
            elsif run("Read request from 0xC81 returns upper 32 bit of system time") then
                systemtimer_value <= X"a1a1a1a1b2b2b2b2";
                csr_in.command <= csr_rw;
                csr_in.address <= X"C81";
                csr_in.data_in <= (others => '0');
                csr_in.do_write <= false;
                csr_in.do_read <= true;
                wait for 1 ns;
                check(not error);
                check_equal(unsigned(read_data), systemtimer_value(63 downto 32));
            elsif run("Read request from 0xC02 returns lower 32 bit of instructions retired counter") then
                instructionsRetired_value <= X"a1a1a1a1b2b2b2b2";
                csr_in.command <= csr_rw;
                csr_in.address <= X"C02";
                csr_in.data_in <= (others => '0');
                csr_in.do_write <= false;
                csr_in.do_read <= true;
                wait for 1 ns;
                check(not error);
                check_equal(unsigned(read_data), instructionsRetired_value(31 downto 0));
            elsif run("Read request from 0xC82 returns upper 32 bit of instructions retired counter") then
                instructionsRetired_value <= X"a1a1a1a1b2b2b2b2";
                csr_in.command <= csr_rw;
                csr_in.address <= X"C82";
                csr_in.data_in <= (others => '0');
                csr_in.do_write <= false;
                csr_in.do_read <= true;
                wait for 1 ns;
                check(not error);
                check_equal(unsigned(read_data), instructionsRetired_value(63 downto 32));
            end if;
        end loop;
        test_runner_cleanup(runner);
        wait;
    end process;

    processor : entity src.riscv32_csr
    port map (
        csr_in => csr_in,
        systemtimer_value => systemtimer_value,
        instructionsRetired_value => instructionsRetired_value,
        read_data => read_data,
        error => error
    );
end architecture;

