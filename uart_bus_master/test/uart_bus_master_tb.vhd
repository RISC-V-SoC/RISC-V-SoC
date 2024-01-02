library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg;
use src.uart_bus_master_pkg;

library tb;
use tb.simulated_bus_memory_pkg;

entity uart_bus_master_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of uart_bus_master_tb is
    constant clk_period : time := 20 ns;
    constant baud_rate : positive := 5000000;

    signal clk : std_logic := '0';
    signal rx : std_logic;
    signal tx : std_logic;

    signal mst2slv : bus_pkg.bus_mst2slv_type;
    signal slv2mst : bus_pkg.bus_slv2mst_type;

    constant uart_slave_bfm : uart_slave_t := new_uart_slave(initial_baud_rate => baud_rate);
    constant uart_slave_stream : stream_slave_t := as_stream(uart_slave_bfm);

    constant uart_master_bfm : uart_master_t := new_uart_master(initial_baud_rate => baud_rate);
    constant uart_master_stream : stream_master_t := as_stream(uart_master_bfm);

    constant slaveActor : actor_t := new_actor("slave");

begin
    clk <= not clk after (clk_period/2);

    main : process
        variable expected_return : std_logic_vector(7 downto 0);
        variable uart_return_data : std_logic_vector(7 downto 0);
        variable return_data : bus_pkg.bus_data_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Erronous command results in command error") then
                push_stream(net, uart_master_stream, x"ff");
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_UNKOWN_COMMAND);
            elsif run("Read command results in no error") then
                push_stream(net, uart_master_stream, uart_bus_master_pkg.COMMAND_READ_WORD);
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
            elsif run("Erronous then legal command works as expected") then
                push_stream(net, uart_master_stream, x"ff");
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_UNKOWN_COMMAND);
                push_stream(net, uart_master_stream, uart_bus_master_pkg.COMMAND_READ_WORD);
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
            elsif run("Unaligned read returns error") then
                expected_return := uart_bus_master_pkg.ERROR_BUS;
                expected_return(7 downto 4) := bus_pkg.bus_fault_unaligned_access;
                push_stream(net, uart_master_stream, uart_bus_master_pkg.COMMAND_READ_WORD);
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
                push_stream(net, uart_master_stream, x"03");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                pop_stream(net, uart_slave_stream, uart_return_data);
                pop_stream(net, uart_slave_stream, uart_return_data);
                pop_stream(net, uart_slave_stream, uart_return_data);
                pop_stream(net, uart_slave_stream, uart_return_data);
                check_stream(net, uart_slave_stream, expected_return);
            elsif run("Aligned read works as expected") then
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000004", X"67452301", X"f");
                push_stream(net, uart_master_stream, uart_bus_master_pkg.COMMAND_READ_WORD);
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
                push_stream(net, uart_master_stream, x"04");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                check_stream(net, uart_slave_stream, x"01");
                check_stream(net, uart_slave_stream, x"23");
                check_stream(net, uart_slave_stream, x"45");
                check_stream(net, uart_slave_stream, x"67");
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
            elsif run("Unaligned read then aligned read works as expected") then
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000004", X"67452301", X"f");
                expected_return := uart_bus_master_pkg.ERROR_BUS;
                expected_return(7 downto 4) := bus_pkg.bus_fault_unaligned_access;
                push_stream(net, uart_master_stream, uart_bus_master_pkg.COMMAND_READ_WORD);
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
                push_stream(net, uart_master_stream, x"03");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                pop_stream(net, uart_slave_stream, uart_return_data);
                pop_stream(net, uart_slave_stream, uart_return_data);
                pop_stream(net, uart_slave_stream, uart_return_data);
                pop_stream(net, uart_slave_stream, uart_return_data);
                check_stream(net, uart_slave_stream, expected_return);
                push_stream(net, uart_master_stream, uart_bus_master_pkg.COMMAND_READ_WORD);
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
                push_stream(net, uart_master_stream, x"04");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                check_stream(net, uart_slave_stream, x"01");
                check_stream(net, uart_slave_stream, x"23");
                check_stream(net, uart_slave_stream, x"45");
                check_stream(net, uart_slave_stream, x"67");
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
            elsif run("Write command results in no error") then
                push_stream(net, uart_master_stream, uart_bus_master_pkg.COMMAND_WRITE_WORD);
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
            elsif run("Normal write command works") then
                push_stream(net, uart_master_stream, uart_bus_master_pkg.COMMAND_WRITE_WORD);
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
                push_stream(net, uart_master_stream, x"04");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"01");
                push_stream(net, uart_master_stream, x"23");
                push_stream(net, uart_master_stream, x"45");
                push_stream(net, uart_master_stream, x"67");
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
                simulated_bus_memory_pkg.read_from_address(net, slaveActor, X"00000004", return_data);
                check(return_data = X"67452301");
            elsif run("Write then read") then
                push_stream(net, uart_master_stream, uart_bus_master_pkg.COMMAND_WRITE_WORD);
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
                push_stream(net, uart_master_stream, x"04");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"01");
                push_stream(net, uart_master_stream, x"23");
                push_stream(net, uart_master_stream, x"45");
                push_stream(net, uart_master_stream, x"67");
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
                push_stream(net, uart_master_stream, uart_bus_master_pkg.COMMAND_READ_WORD);
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
                push_stream(net, uart_master_stream, x"04");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                check_stream(net, uart_slave_stream, x"01");
                check_stream(net, uart_slave_stream, x"23");
                check_stream(net, uart_slave_stream, x"45");
                check_stream(net, uart_slave_stream, x"67");
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
            elsif run("Double write") then
                push_stream(net, uart_master_stream, uart_bus_master_pkg.COMMAND_WRITE_WORD);
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"01");
                push_stream(net, uart_master_stream, x"23");
                push_stream(net, uart_master_stream, x"45");
                push_stream(net, uart_master_stream, x"67");
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
                push_stream(net, uart_master_stream, uart_bus_master_pkg.COMMAND_WRITE_WORD);
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
                push_stream(net, uart_master_stream, x"04");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"89");
                push_stream(net, uart_master_stream, x"ab");
                push_stream(net, uart_master_stream, x"cd");
                push_stream(net, uart_master_stream, x"ef");
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
                simulated_bus_memory_pkg.read_from_address(net, slaveActor, X"00000000", return_data);
                check(return_data = X"67452301");
                simulated_bus_memory_pkg.read_from_address(net, slaveActor, X"00000004", return_data);
                check(return_data = X"efcdab89");
            elsif run("Aligned read then aligned read works") then
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000000", X"33333333", X"f");
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000004", X"44444444", X"f");
                push_stream(net, uart_master_stream, uart_bus_master_pkg.COMMAND_READ_WORD);
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                check_stream(net, uart_slave_stream, x"33");
                check_stream(net, uart_slave_stream, x"33");
                check_stream(net, uart_slave_stream, x"33");
                check_stream(net, uart_slave_stream, x"33");
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
                push_stream(net, uart_master_stream, uart_bus_master_pkg.COMMAND_READ_WORD);
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
                push_stream(net, uart_master_stream, x"04");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                check_stream(net, uart_slave_stream, x"44");
                check_stream(net, uart_slave_stream, x"44");
                check_stream(net, uart_slave_stream, x"44");
                check_stream(net, uart_slave_stream, x"44");
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
            elsif run("Write sequence") then
                push_stream(net, uart_master_stream, uart_bus_master_pkg.COMMAND_WRITE_WORD_SEQUENCE);
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"03");
                push_stream(net, uart_master_stream, x"11");
                push_stream(net, uart_master_stream, x"11");
                push_stream(net, uart_master_stream, x"11");
                push_stream(net, uart_master_stream, x"11");
                push_stream(net, uart_master_stream, x"22");
                push_stream(net, uart_master_stream, x"22");
                push_stream(net, uart_master_stream, x"22");
                push_stream(net, uart_master_stream, x"22");
                push_stream(net, uart_master_stream, x"33");
                push_stream(net, uart_master_stream, x"33");
                push_stream(net, uart_master_stream, x"33");
                push_stream(net, uart_master_stream, x"33");
                push_stream(net, uart_master_stream, x"44");
                push_stream(net, uart_master_stream, x"44");
                push_stream(net, uart_master_stream, x"44");
                push_stream(net, uart_master_stream, x"44");
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
                simulated_bus_memory_pkg.read_from_address(net, slaveActor, X"00000000", return_data);
                check(return_data = X"11111111");
                simulated_bus_memory_pkg.read_from_address(net, slaveActor, X"00000004", return_data);
                check(return_data = X"22222222");
                simulated_bus_memory_pkg.read_from_address(net, slaveActor, X"00000008", return_data);
                check(return_data = X"33333333");
                simulated_bus_memory_pkg.read_from_address(net, slaveActor, X"0000000c", return_data);
                check(return_data = X"44444444");
            elsif run("Read sequence") then
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000000", X"11111111", X"f");
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000004", X"22222222", X"f");
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"00000008", X"33333333", X"f");
                simulated_bus_memory_pkg.write_to_address(net, slaveActor, X"0000000c", X"44444444", X"f");
                push_stream(net, uart_master_stream, uart_bus_master_pkg.COMMAND_READ_WORD_SEQUENCE);
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"00");
                push_stream(net, uart_master_stream, x"03");
                check_stream(net, uart_slave_stream, x"11");
                check_stream(net, uart_slave_stream, x"11");
                check_stream(net, uart_slave_stream, x"11");
                check_stream(net, uart_slave_stream, x"11");
                check_stream(net, uart_slave_stream, x"22");
                check_stream(net, uart_slave_stream, x"22");
                check_stream(net, uart_slave_stream, x"22");
                check_stream(net, uart_slave_stream, x"22");
                check_stream(net, uart_slave_stream, x"33");
                check_stream(net, uart_slave_stream, x"33");
                check_stream(net, uart_slave_stream, x"33");
                check_stream(net, uart_slave_stream, x"33");
                check_stream(net, uart_slave_stream, x"44");
                check_stream(net, uart_slave_stream, x"44");
                check_stream(net, uart_slave_stream, x"44");
                check_stream(net, uart_slave_stream, x"44");
                check_stream(net, uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner,  1 ms);

    bus_master : entity src.uart_bus_master
    generic map (
        clk_period => clk_period,
        baud_rate => baud_rate
    ) port map (
        clk => clk,
        tx => tx,
        rx => rx,
        mst2slv => mst2slv,
        slv2mst => slv2mst
    );

    uart_slave : entity vunit_lib.uart_slave
    generic map (
      uart => uart_slave_bfm)
    port map (
      rx => tx);

    uart_master : entity vunit_lib.uart_master
    generic map (
      uart => uart_master_bfm)
    port map (
      tx => rx);

    bus_slave : entity tb.simulated_bus_memory
    generic map (
        depth_log2b => 4,
        allow_unaligned_access => false,
        actor => slaveActor,
        read_delay => 5,
        write_delay => 5
    ) port map (
        clk => clk,
        mst2mem => mst2slv,
        mem2mst => slv2mst
    );
end architecture;
