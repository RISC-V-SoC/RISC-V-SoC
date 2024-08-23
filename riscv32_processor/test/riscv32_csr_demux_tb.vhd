library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.riscv32_pkg.all;

entity riscv32_csr_demux_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_csr_demux_tb is
    signal csr_in : riscv32_to_csr_type;
    signal read_data : riscv32_data_type;
    signal error : boolean;

    constant mapping_array : riscv32_csr_mapping_array := (
        (address_low => 16#C00#, mapping_size => 16#C0#),
        (address_low => 16#300#, mapping_size => 16#11#)
    );

    signal demux2user_readonly : riscv32_csr_mst2slv_type;
    signal demux2machine_trap_handling : riscv32_csr_mst2slv_type;

    signal user_readonly2demux : riscv32_csr_slv2mst_type;
    signal machine_trap_handling2demux : riscv32_csr_slv2mst_type;
begin
    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Read from address 0x100 results in error") then
                csr_in.command <= csr_rw;
                csr_in.address <= std_logic_vector(to_unsigned(16#100#, csr_in.address'length));
                csr_in.data_in <= (others => '0');
                csr_in.do_write <= false;
                csr_in.do_read <= true;
                wait for 1 ns;
                check_true(error);
            elsif run("Read from address 0xC00 does not result in error") then
                csr_in.command <= csr_rw;
                csr_in.address <= std_logic_vector(to_unsigned(16#C00#, csr_in.address'length));
                csr_in.data_in <= (others => '0');
                csr_in.do_write <= false;
                csr_in.do_read <= true;
                wait for 1 ns;
                check_false(error);
            elsif run("No read or write with address 0x100 results in no error") then
                csr_in.command <= csr_rw;
                csr_in.address <= std_logic_vector(to_unsigned(16#100#, csr_in.address'length));
                csr_in.data_in <= (others => '0');
                csr_in.do_write <= false;
                csr_in.do_read <= false;
                wait for 1 ns;
                check_false(error);
            elsif run("Read from address 0xC01 results in user_readonly read with address 1") then
                csr_in.command <= csr_rw;
                csr_in.address <= std_logic_vector(to_unsigned(16#C01#, csr_in.address'length));
                csr_in.data_in <= (others => '0');
                csr_in.do_write <= false;
                csr_in.do_read <= true;
                wait for 1 ns;
                check_true(demux2user_readonly.do_read);
                check_equal(demux2user_readonly.address, 1);
            elsif run("Read from address 0x302 results in machine_trap_handling read with address 2") then
                csr_in.command <= csr_rw;
                csr_in.address <= std_logic_vector(to_unsigned(16#302#, csr_in.address'length));
                csr_in.data_in <= (others => '0');
                csr_in.do_write <= false;
                csr_in.do_read <= true;
                wait for 1 ns;
                check_true(demux2machine_trap_handling.do_read);
                check_equal(demux2machine_trap_handling.address, 2);
            elsif run("Read from address 0xC01 results in read_data from user_readonly") then
                csr_in.command <= csr_rw;
                csr_in.address <= std_logic_vector(to_unsigned(16#C01#, csr_in.address'length));
                csr_in.data_in <= (others => '0');
                csr_in.do_write <= false;
                csr_in.do_read <= true;
                user_readonly2demux.read_data <= std_logic_vector(to_unsigned(16#1234#, user_readonly2demux.read_data'length));
                wait for 1 ns;
                check_equal(read_data, user_readonly2demux.read_data);
            elsif run("Read from address 0x302 results in read_data from machine_trap_handling") then
                csr_in.command <= csr_rw;
                csr_in.address <= std_logic_vector(to_unsigned(16#302#, csr_in.address'length));
                csr_in.data_in <= (others => '0');
                csr_in.do_write <= false;
                csr_in.do_read <= true;
                machine_trap_handling2demux.read_data <= std_logic_vector(to_unsigned(16#5678#, machine_trap_handling2demux.read_data'length));
                wait for 1 ns;
                check_equal(read_data, machine_trap_handling2demux.read_data);
            elsif run("Error from address 0xC02 is forwarded") then
                csr_in.command <= csr_rw;
                csr_in.address <= std_logic_vector(to_unsigned(16#C02#, csr_in.address'length));
                csr_in.data_in <= (others => '0');
                csr_in.do_write <= false;
                csr_in.do_read <= true;
                user_readonly2demux.has_error <= true;
                wait for 1 ns;
                check_true(error);
            elsif run("Write to user_readonly address 0xC03 results in error") then
                csr_in.command <= csr_rw;
                csr_in.address <= std_logic_vector(to_unsigned(16#C03#, csr_in.address'length));
                csr_in.data_in <= std_logic_vector(to_unsigned(16#1234#, csr_in.data_in'length));
                csr_in.do_write <= true;
                csr_in.do_read <= false;
                wait for 1 ns;
                check_true(error);
            elsif run("RW to machine_trap_handling address 0x303 results in write to machine_trap_handling") then
                csr_in.command <= csr_rw;
                csr_in.address <= std_logic_vector(to_unsigned(16#303#, csr_in.address'length));
                csr_in.data_in <= std_logic_vector(to_unsigned(16#1234#, csr_in.data_in'length));
                csr_in.do_write <= true;
                csr_in.do_read <= false;
                wait for 1 ns;
                check_true(demux2machine_trap_handling.do_write);
                check_equal(demux2machine_trap_handling.write_data, csr_in.data_in);
            elsif run("RW to user_readonly address 0xC03 does not forward do_write or do_read") then
                csr_in.command <= csr_rw;
                csr_in.address <= std_logic_vector(to_unsigned(16#C03#, csr_in.address'length));
                csr_in.data_in <= std_logic_vector(to_unsigned(16#1234#, csr_in.data_in'length));
                csr_in.do_write <= true;
                csr_in.do_read <= true;
                wait for 1 ns;
                check_false(demux2user_readonly.do_write);
                check_false(demux2user_readonly.do_read);
            elsif run("CSRRS to machine_trap_handling address 0x303 results in a read and set bits") then
                csr_in.command <= csr_rs;
                csr_in.address <= std_logic_vector(to_unsigned(16#303#, csr_in.address'length));
                csr_in.data_in <= std_logic_vector(to_unsigned(16#f#, csr_in.data_in'length));
                csr_in.do_write <= true;
                csr_in.do_read <= true;
                machine_trap_handling2demux.read_data <= std_logic_vector(to_unsigned(16#f0#, machine_trap_handling2demux.read_data'length));
                wait for 1 ns;
                check_equal(demux2machine_trap_handling.write_data, std_logic_vector(to_unsigned(16#ff#, demux2machine_trap_handling.write_data'length)));
            elsif run("CSRRC to machine_trap_handling address 0x303 results in a read and set bits") then
                csr_in.command <= csr_rc;
                csr_in.address <= std_logic_vector(to_unsigned(16#303#, csr_in.address'length));
                csr_in.data_in <= std_logic_vector(to_unsigned(16#f0f#, csr_in.data_in'length));
                csr_in.do_write <= true;
                csr_in.do_read <= true;
                machine_trap_handling2demux.read_data <= std_logic_vector(to_unsigned(16#fff#, machine_trap_handling2demux.read_data'length));
                wait for 1 ns;
                check_equal(demux2machine_trap_handling.write_data, std_logic_vector(to_unsigned(16#0f0#, demux2machine_trap_handling.write_data'length)));
            end if;
        end loop;
        test_runner_cleanup(runner);
        wait;
    end process;

    csr_demux : entity src.riscv32_csr_demux
    generic map (
        mapping_array => mapping_array
    ) port map (
        csr_in => csr_in,
        read_data => read_data,
        error => error,
        demux2slv(0) => demux2user_readonly,
        demux2slv(1) => demux2machine_trap_handling,
        slv2demux(0) => user_readonly2demux,
        slv2demux(1) => machine_trap_handling2demux
    );
end architecture;
