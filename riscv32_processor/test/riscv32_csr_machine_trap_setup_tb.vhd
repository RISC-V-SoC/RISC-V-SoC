library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.riscv32_pkg.all;

entity riscv32_csr_machine_trap_setup_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_csr_machine_trap_setup_tb is
        constant clk_period : time := 20 ns;
        signal clk : std_logic := '0';
        signal rst : boolean := false;
        signal address : std_logic_vector(7 downto 0) := (others => '0');
        signal read_data : riscv32_data_type;
        signal write_data : riscv32_data_type := (others => '0');
        signal do_write : boolean := false;
        signal address_out_of_range : boolean;

        signal interrupts_enabled : boolean;
        signal interrupt_trigger : boolean := false;

        signal m_timer_interrupt_enabled : boolean;
        signal m_external_interrupt_enabled : boolean;
begin
    clk <= not clk after (clk_period/2);
    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Read from address 2 results in address_out_of_range") then
                address <= std_logic_vector(to_unsigned(2, address'length));
                wait for 1 ns;
                check_true(address_out_of_range);
            elsif run("Read from address 0 does not result in address_out_of_range") then
                address <= std_logic_vector(to_unsigned(0, address'length));
                wait for 1 ns;
                check_false(address_out_of_range);
            elsif run("Writing 1 to mstatus.MIE enables interrupts") then
                address <= std_logic_vector(to_unsigned(0, address'length));
                write_data <= x"00000008";
                do_write <= true;
                wait for clk_period;
                check_true(interrupts_enabled);
            elsif run("Interrupts are default disabled") then
                check_false(interrupts_enabled);
            elsif run("Writing 1 to mstatus.MIE in wrong register does not enable interrupts") then
                address <= std_logic_vector(to_unsigned(2, address'length));
                write_data <= x"00000008";
                do_write <= true;
                wait for clk_period;
                check_false(interrupts_enabled);
            elsif run("On do_write is false, write is ignored") then
                address <= std_logic_vector(to_unsigned(0, address'length));
                write_data <= x"00000008";
                do_write <= false;
                wait for clk_period;
                check_false(interrupts_enabled);
            elsif run("Write 1 to mstatus.MIE then read mstatus.MIE results in 1") then
                address <= std_logic_vector(to_unsigned(0, address'length));
                write_data <= x"00000008";
                do_write <= true;
                wait for clk_period;
                check_equal(read_data, std_logic_vector'(x"00000008"));
            elsif run("mstatus readonly fields remain at zero") then
                address <= std_logic_vector(to_unsigned(0, address'length));
                write_data <= (others => '1');
                do_write <= true;
                wait for clk_period;
                check_equal(read_data, std_logic_vector'(x"000019aa"));
            elsif run("Check interrupt_trigger response") then
                address <= std_logic_vector(to_unsigned(0, address'length));
                write_data <= x"00000008";
                do_write <= true;
                wait for clk_period;
                do_write <= false;
                interrupt_trigger <= true;
                wait for clk_period;
                interrupt_trigger <= false;
                -- Interrupts should be disabled
                check_false(interrupts_enabled);
                check_equal(read_data(3), '0');
                -- mstatus.MPP should be equal to machine mode
                check_equal(read_data(12 downto 11), riscv32_privilege_level_machine);
                -- mstatus.MPIE should be set to 1, since mstatus.MIE was one
                check_equal(read_data(7), '1');
            elsif run("mstatus.MPIE is 0 if mstatus.MIE was 0 before interrupt") then
                address <= std_logic_vector(to_unsigned(0, address'length));
                write_data <= (others => '0');
                do_write <= true;
                wait for clk_period;
                do_write <= false;
                interrupt_trigger <= true;
                wait for clk_period;
                interrupt_trigger <= false;
                -- Interrupts should be disabled
                check_false(interrupts_enabled);
                check_equal(read_data(3), '0');
                -- mstatus.MPP should be equal to machine mode
                check_equal(read_data(12 downto 11), riscv32_privilege_level_machine);
                -- mstatus.MPIE should be set to 0, since mstatus.MIE was zero
                check_equal(read_data(7), '0');
            elsif run("reset resets mstatus") then
                address <= std_logic_vector(to_unsigned(0, address'length));
                write_data <= (others => '1');
                do_write <= true;
                wait for clk_period;
                do_write <= false;
                rst <= true;
                wait for clk_period;
                rst <= false;
                check_equal(read_data, std_logic_vector'(x"00000000"));
            elsif run("Reading from misa does not result in error") then
                address <= std_logic_vector(to_unsigned(1, address'length));
                wait for clk_period;
                check_false(address_out_of_range);
            elsif run("misa.MXL is set to 1") then
                address <= std_logic_vector(to_unsigned(1, address'length));
                wait for clk_period;
                check_equal(read_data(read_data'high downto read_data'high -1), std_logic_vector'("01"));
            elsif run("misa only indicates I extension support") then
                address <= std_logic_vector(to_unsigned(1, address'length));
                wait for clk_period;
                check_equal(read_data(25 downto 9), std_logic_vector'("00000000000000000"));
                check_equal(read_data(8), '1');
                check_equal(read_data(7 downto 0), std_logic_vector'("00000000"));
            elsif run("Writing to misa has no effects") then
                address <= std_logic_vector(to_unsigned(1, address'length));
                write_data <= (others => '1');
                do_write <= true;
                wait for clk_period;
                do_write <= false;
                wait for clk_period;
                check_equal(read_data(25 downto 9), std_logic_vector'("00000000000000000"));
                check_equal(read_data(8), '1');
                check_equal(read_data(7 downto 0), std_logic_vector'("00000000"));
                check_false(address_out_of_range);
            elsif run("Reading from mie does not result in error") then
                address <= std_logic_vector(to_unsigned(4, address'length));
                wait for clk_period;
                check_false(address_out_of_range);
            elsif run("Setting mie.MTIE enables machine timer interrupt") then
                address <= std_logic_vector(to_unsigned(4, address'length));
                write_data <= x"00000080";
                do_write <= true;
                wait for clk_period;
                check_true(m_timer_interrupt_enabled);
            elsif run("Setting mie.MEIE enables machine external interrupt") then
                address <= std_logic_vector(to_unsigned(4, address'length));
                write_data <= x"00000800";
                do_write <= true;
                wait for clk_period;
                check_true(m_external_interrupt_enabled);
            elsif run("All other bits are readonly zero in mie") then
                address <= std_logic_vector(to_unsigned(4, address'length));
                write_data <= (others => '1');
                do_write <= true;
                wait for clk_period;
                check_equal(read_data, std_logic_vector'(x"00000880"));
            elsif run("Reading from mtvec does not result in error") then
                address <= std_logic_vector(to_unsigned(5, address'length));
                wait for clk_period;
                check_false(address_out_of_range);
            elsif run("mtvec.MODE is 1") then
                address <= std_logic_vector(to_unsigned(5, address'length));
                wait for clk_period;
                check_equal(read_data(1 downto 0), std_logic_vector'("01"));
            elsif run("mtvec.BASE can be set") then
                address <= std_logic_vector(to_unsigned(5, address'length));
                write_data <= (others => '1');
                do_write <= true;
                wait for clk_period;
                check_equal(and_reduce(read_data(read_data'high downto 2)), '1');
            elsif run("mtvec.MODE cannot be overwritten") then
                address <= std_logic_vector(to_unsigned(5, address'length));
                write_data <= (others => '1');
                do_write <= true;
                wait for clk_period;
                check_equal(read_data(1 downto 0), std_logic_vector'("01"));
            elsif run("Reading from mstatush does not result in error") then
                address <= std_logic_vector(to_unsigned(16, address'length));
                wait for clk_period;
                check_false(address_out_of_range);
            end if;
        end loop;
        test_runner_cleanup(runner);
        wait;
    end process;

    csr_machine_trap_setup : entity src.riscv32_csr_machine_trap_setup
    port map (
        clk => clk,
        rst => rst,
        address => address,
        read_data => read_data,
        write_data => write_data,
        do_write => do_write,
        address_out_of_range => address_out_of_range,
        interrupts_enabled => interrupts_enabled,
        interrupt_trigger => interrupt_trigger,
        m_timer_interrupt_enabled => m_timer_interrupt_enabled,
        m_external_interrupt_enabled => m_external_interrupt_enabled
    );
end architecture;
