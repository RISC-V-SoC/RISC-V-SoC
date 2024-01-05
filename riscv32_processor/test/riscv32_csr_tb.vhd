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
            end if;
        end loop;
        test_runner_cleanup(runner);
        wait;
    end process;

    processor : entity src.riscv32_csr
    port map (
        csr_in => csr_in,
        read_data => read_data,
        error => error
    );
end architecture;

