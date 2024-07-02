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

    signal address_to_user_readonly : std_logic_vector(7 downto 0);
    signal read_data_from_user_readonly : riscv32_data_type := (others => '0');
    signal error_from_user_readonly : boolean := false;
begin
    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Read from 0xC00 reads from unpriviledged_readonly at address 0, not high") then
                csr_in.command <= csr_rw;
                csr_in.address <= X"c00";
                csr_in.data_in <= (others => '0');
                csr_in.do_write <= false;
                csr_in.do_read <= true;
                read_data_from_user_readonly <= (others => '1');
                wait for 1 ns;
                check_equal(address_to_user_readonly, std_logic_vector'(X"00"));
                check_equal(read_data, read_data_from_user_readonly);
            elsif run("Read from 0xC01 reads from unpriviledged_readonly at address 1") then
                csr_in.command <= csr_rw;
                csr_in.address <= X"c01";
                csr_in.data_in <= (others => '0');
                csr_in.do_write <= false;
                csr_in.do_read <= true;
                wait for 1 ns;
                check_equal(address_to_user_readonly, 1);
            elsif run("Read from 0xC82 reads from unpriviledged_readonly at address 0x82") then
                csr_in.command <= csr_rw;
                csr_in.address <= X"c82";
                csr_in.data_in <= (others => '0');
                csr_in.do_write <= false;
                csr_in.do_read <= true;
                wait for 1 ns;
                check_equal(address_to_user_readonly, std_logic_vector'(X"82"));
            elsif run("Error from 0xC03 is forwarded") then
                csr_in.command <= csr_rw;
                csr_in.address <= X"c03";
                csr_in.data_in <= (others => '0');
                csr_in.do_write <= false;
                csr_in.do_read <= true;
                error_from_user_readonly <= true;
                wait for 1 ns;
                check_true(error);
            elsif run("Write to read-only always results in error") then
                csr_in.command <= csr_rw;
                csr_in.address <= X"c00";
                csr_in.data_in <= (others => '0');
                csr_in.do_write <= true;
                csr_in.do_read <= true;
                wait for 1 ns;
                check_true(error);
            elsif run("Fault if first two bits of address are not 1") then
                csr_in.command <= csr_rw;
                csr_in.address <= X"800";
                csr_in.data_in <= (others => '0');
                csr_in.do_write <= false;
                csr_in.do_read <= true;
                wait for 1 ns;
                check_true(error);
            end if;
        end loop;
        test_runner_cleanup(runner);
        wait;
    end process;

    csr : entity src.riscv32_csr
    port map (
        csr_in => csr_in,
        read_data => read_data,
        error => error,
        address_to_user_readonly => address_to_user_readonly,
        read_data_from_user_readonly => read_data_from_user_readonly,
        error_from_user_readonly => error_from_user_readonly
    );
end architecture;

