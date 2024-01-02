library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library tb;

library src;
use src.bus_pkg.all;
use src.uart_bus_master_pkg;

entity main_file_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of main_file_tb is
    constant clk_period : time := 10 ns;
    constant baud_rate : positive := 2000000;

    constant command_uart_slave_bfm : uart_slave_t := new_uart_slave(initial_baud_rate => baud_rate);
    constant command_uart_slave_stream : stream_slave_t := as_stream(command_uart_slave_bfm);
    constant command_uart_master_bfm : uart_master_t := new_uart_master(initial_baud_rate => baud_rate);
    constant command_uart_master_stream : stream_master_t := as_stream(command_uart_master_bfm);

    constant slave_uart_slave_bfm : uart_slave_t := new_uart_slave(initial_baud_rate => 115200);
    constant slave_uart_slave_stream : stream_slave_t := as_stream(slave_uart_slave_bfm);
    constant slave_uart_master_bfm : uart_master_t := new_uart_master(initial_baud_rate => 115200);
    constant slave_uart_master_stream : stream_master_t := as_stream(slave_uart_master_bfm);

    signal clk : std_logic := '0';
    signal rx : std_logic;
    signal tx : std_logic;
    -- SPI mem
    signal cs_n : std_logic_vector(2 downto 0);
    signal so_sio1 : std_logic;
    signal sio2 : std_logic;
    signal hold_n_sio3 : std_logic;
    signal sck : std_logic;
    signal si_sio0 : std_logic;
    -- UART slave
    signal slv_tx : std_logic;
    signal slv_rx : std_logic;

    signal rst : std_logic := '0';

    procedure write(
        signal net : inout network_t;
        constant addr : in bus_address_type;
        constant data : in bus_data_type) is
    begin
        push_stream(net, command_uart_master_stream, uart_bus_master_pkg.COMMAND_WRITE_WORD);
        check_stream(net, command_uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
        for i in 0 to bus_bytes_per_word - 1 loop
            push_stream(net, command_uart_master_stream, addr(i*8 + 7 downto i*8));
        end loop;
        for i in 0 to bus_bytes_per_word - 1 loop
            push_stream(net, command_uart_master_stream, data(i*8 + 7 downto i*8));
        end loop;
        check_stream(net, command_uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
    end procedure;

    procedure read(
        signal net : inout network_t;
        constant addr : in bus_address_type;
        constant data : in bus_data_type) is
    begin
        push_stream(net, command_uart_master_stream, uart_bus_master_pkg.COMMAND_READ_WORD);
        check_stream(net, command_uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
        for i in 0 to bus_bytes_per_word - 1 loop
            push_stream(net, command_uart_master_stream, addr(i*8 + 7 downto i*8));
        end loop;
        for i in 0 to bus_bytes_per_word - 1 loop
            check_stream(net, command_uart_slave_stream, data(i*8 + 7 downto i*8));
        end loop;
        check_stream(net, command_uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
    end procedure;

    procedure write_file(
            signal net : inout network_t;
            constant addr : in bus_address_type;
            constant fileName : in string) is
        file read_file : text;
        variable line_v : line;
        variable data : bus_data_type;
        variable address : natural;
        variable busAddress : bus_address_type;
    begin
        address := to_integer(unsigned(addr));
        file_open(read_file, fileName, read_mode);
        while not endfile(read_file) loop
            readline(read_file, line_v);
            hread(line_v, data);
            busAddress := std_logic_vector(to_unsigned(address, busAddress'length));
            write(net, busAddress, data);
            address := address + 4;
        end loop;
        file_close(read_file);
    end;
begin
    clk <= not clk after (clk_period/2);
    process
        constant processor_controller_start_address : bus_address_type := std_logic_vector(to_unsigned(16#2000#, bus_address_type'length));

        constant spimem0_start_address : bus_address_type := std_logic_vector(to_unsigned(16#100000#, bus_address_type'length));
        constant spimem1_start_address : bus_address_type := std_logic_vector(to_unsigned(16#120000#, bus_address_type'length));
        constant spimem2_start_address : bus_address_type := std_logic_vector(to_unsigned(16#140000#, bus_address_type'length));

        variable curAddr : natural;
        variable address : bus_address_type;
        variable expectedData : bus_data_type;
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Spi mem is usable") then
                write(net, spimem0_start_address, X"01020304");
                read(net, spimem0_start_address, X"01020304");
            elsif run("Riscv32: bubblesort") then
                write_file(net, spimem0_start_address, "./complete_system/test/programs/fullBubblesort.txt");
                write(net, processor_controller_start_address, X"00000000");
                wait for 300 us;
                curAddr := 16#00120000#;
                for i in -6 to 5 loop
                    address := std_logic_vector(to_unsigned(curAddr, address'length));
                    curAddr := curAddr + 4;
                    expectedData := std_logic_vector(to_signed(i, expectedData'length));
                    read(net, address, expectedData);
                end loop;
                curAddr := 16#00120030#;
                for i in -3 to 2 loop
                    address := std_logic_vector(to_unsigned(curAddr, address'length));
                    expectedData(31 downto 16) := std_logic_vector(to_signed(i*2 + 1, 16));
                    expectedData(15 downto 0) := std_logic_vector(to_signed(i*2, 16));
                    read(net, address, expectedData);
                    curAddr := curAddr + 4;
                end loop;
                curAddr := 16#00120048#;
                for i in 0 to 2 loop
                    address := std_logic_vector(to_unsigned(curAddr, address'length));
                    expectedData(31 downto 24) := std_logic_vector(to_signed(i*4 - 3, 8));
                    expectedData(23 downto 16) := std_logic_vector(to_signed(i*4 - 4, 8));
                    expectedData(15 downto 8) := std_logic_vector(to_signed(i*4 - 5, 8));
                    expectedData(7 downto 0) := std_logic_vector(to_signed(i*4 - 6, 8));
                    read(net, address, expectedData);
                    curAddr := curAddr + 4;
                end loop;
            elsif run("Riscv32 UART test") then
                write_file(net, spimem0_start_address, "./complete_system/test/programs/uartTest.txt");
                write(net, processor_controller_start_address, X"00000000");
                wait for 200 us;
                push_stream(net, slave_uart_master_stream, X"61");
                check_stream(net, slave_uart_slave_stream, X"61");
            end if;
        end loop;
        wait until rising_edge(clk) or falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    test_runner_watchdog(runner, 20 ms);

    mem_pcb : entity tb.triple_M23LC1024
    port map (
        cs_n => cs_n,
        so_sio1 => so_sio1,
        sio2 => sio2,
        hold_n_sio3 => hold_n_sio3,
        sck => sck,
        si_sio0 => si_sio0
    );

    main_file : entity src.main_file
    generic map (
        clk_period => clk_period,
        baud_rate => baud_rate
    ) port map (
        JA_gpio(0) => si_sio0,
        JA_gpio(1) => so_sio1,
        JA_gpio(2) => sio2,
        JA_gpio(3) => hold_n_sio3,
        JB_gpio(3 downto 1) => cs_n,
        JB_gpio(0) => sck,
        clk => clk,
        global_reset => rst,
        master_rx => rx,
        master_tx => tx,
        slave_rx => slv_rx,
        slave_tx => slv_tx
    );

    command_uart_slave : entity vunit_lib.uart_slave
    generic map (
      uart => command_uart_slave_bfm)
    port map (
      rx => tx);

    command_uart_master : entity vunit_lib.uart_master
    generic map (
      uart => command_uart_master_bfm)
    port map (
      tx => rx);

    slave_uart_slave : entity vunit_lib.uart_slave
    generic map (
      uart => slave_uart_slave_bfm)
    port map (
      rx => slv_tx);

    slave_uart_master : entity vunit_lib.uart_master
    generic map (
      uart => slave_uart_master_bfm)
    port map (
      tx => slv_rx);
end architecture;
