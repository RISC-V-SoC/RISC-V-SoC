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
    constant logger : logger_t := get_logger("Complete system test");

    constant l2cache_words_per_line_log2b : natural := 3;
    constant l2cache_words_per_line : natural := 2**l2cache_words_per_line_log2b;

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

    signal general_gpio : std_logic_vector(7 downto 0);

    -- SPI Device
    signal spi_ss : std_logic;
    signal spi_clk : std_logic;
    signal spi_mosi_miso : std_logic;

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

    procedure read_word(
        signal net : inout network_t;
        constant addr : in bus_address_type;
        variable data : out bus_data_type) is
        variable stream_word : std_logic_vector(7 downto 0);
    begin
        push_stream(net, command_uart_master_stream, uart_bus_master_pkg.COMMAND_READ_WORD);
        check_stream(net, command_uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
        for i in 0 to bus_bytes_per_word - 1 loop
            push_stream(net, command_uart_master_stream, addr(i*8 + 7 downto i*8));
        end loop;
        for i in 0 to bus_bytes_per_word - 1 loop
            pop_stream(net, command_uart_slave_stream, stream_word);
            data(i*8 + 7 downto i*8) := stream_word;
        end loop;
        check_stream(net, command_uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
    end procedure;

    procedure flush_cache(
        signal net : inout network_t) is
        variable data : bus_data_type;
        variable address : bus_address_type;
    begin
        data := X"00000006";
        address := std_logic_vector(to_unsigned(16#2000#, bus_address_type'length));
        write(net, address, data);
        address := std_logic_vector(to_unsigned(16#2000# + 16, bus_address_type'length));
        while true loop
            wait for 1 us;
            read_word(net, address, data);
            exit when data(0) = '0';
        end loop;
    end procedure;

    procedure write_buffer(
        signal net : inout network_t;
        constant addr : in bus_address_type;
        constant data : in bus_data_array;
        constant count : in natural range 1 to 64) is
        variable seq_size_minus_one : bus_byte_type;
    begin
        seq_size_minus_one := std_logic_vector(to_unsigned(count - 1, seq_size_minus_one'length));
        push_stream(net, command_uart_master_stream, uart_bus_master_pkg.COMMAND_WRITE_WORD_SEQUENCE);
        check_stream(net, command_uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
        for i in 0 to bus_bytes_per_word - 1 loop
            push_stream(net, command_uart_master_stream, addr(i*8 + 7 downto i*8));
        end loop;
        push_stream(net, command_uart_master_stream, seq_size_minus_one);
        for i in 0 to count - 1 loop
            for j in 0 to bus_bytes_per_word - 1 loop
                push_stream(net, command_uart_master_stream, data(i)(j*8 + 7 downto j*8));
            end loop;
        end loop;
        check_stream(net, command_uart_slave_stream, uart_bus_master_pkg.ERROR_NO_ERROR);
    end procedure;

    procedure write_file(
            signal net : inout network_t;
            constant addr : in bus_address_type;
            constant fileName : in string) is
        file read_file : text;
        variable line_v : line;
        variable data : bus_data_array(0 to 63);
        variable address : natural;
        variable busAddress : bus_address_type;
        variable count : natural range 0 to 64;
    begin
        address := to_integer(unsigned(addr));
        file_open(read_file, fileName, read_mode);
        while not endfile(read_file) loop
            readline(read_file, line_v);
            hread(line_v, data(count));
            count := count + 1;
            if count = 64 then
                busAddress := std_logic_vector(to_unsigned(address, busAddress'length));
                write_buffer(net, busAddress, data, count);
                address := address + (64 * 4);
                count := 0;
            end if;
        end loop;
        if count > 0 then
            busAddress := std_logic_vector(to_unsigned(address, busAddress'length));
            write_buffer(net, busAddress, data, count);
        end if;
        file_close(read_file);
    end procedure;
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
                for i in 0 to l2cache_words_per_line - 1 loop
                    write(net, std_logic_vector(unsigned(spimem0_start_address) + i*4), std_logic_vector(to_unsigned(i, bus_data_type'length)));
                end loop;
                flush_cache(net);
                for i in 0 to l2cache_words_per_line - 1 loop
                    read(net, std_logic_vector(unsigned(spimem0_start_address) + i*4), std_logic_vector(to_unsigned(i, bus_data_type'length)));
                end loop;
            elsif run("Riscv32: bubblesort") then
                write(net, processor_controller_start_address, X"00000001");
                write_file(net, spimem0_start_address, "./complete_system/test/programs/fullBubblesort.txt");
                write(net, processor_controller_start_address, X"00000000");
                wait for 200 us;
                flush_cache(net);
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
            elsif run("GPIO test") then
                write_file(net, spimem0_start_address, "./complete_system/test/programs/gpioTest.txt");
                write(net, processor_controller_start_address, X"00000000");
                general_gpio(0) <= '1';
                check_stream(net, slave_uart_slave_stream, X"31");
            elsif run("Run same uart program multiple times") then
                write(net, processor_controller_start_address, X"00000001");
                write_file(net, spimem0_start_address, "./complete_system/test/programs/uart_hw.txt");
                flush_cache(net);
                for i in 0 to 5 loop
                    info(logger, "Iteration " & integer'image(i + 1) & " of 5");
                    write(net, processor_controller_start_address, X"00000001");
                    write(net, processor_controller_start_address, X"00000000");
                    check_stream(net, slave_uart_slave_stream, X"68");
                    check_stream(net, slave_uart_slave_stream, X"77");
                    check_stream(net, slave_uart_slave_stream, X"21");
                    check_stream(net, slave_uart_slave_stream, X"0D");
                    check_stream(net, slave_uart_slave_stream, X"0A");
                end loop;
            elsif run("SPI test") then
                write_file(net, spimem0_start_address, "./complete_system/test/programs/spi_test.txt");
                write(net, processor_controller_start_address, X"00000000");
                check_stream(net, slave_uart_slave_stream, X"4F");
                check_stream(net, slave_uart_slave_stream, X"4B");
                check_stream(net, slave_uart_slave_stream, X"0D");
                check_stream(net, slave_uart_slave_stream, X"0A");
            elsif run("IM based UART test") then
                write_file(net, spimem0_start_address, "./complete_system/test/programs/uartTestIM.txt");
                write(net, processor_controller_start_address, X"00000000");
                check_stream(net, slave_uart_slave_stream, X"68");
                check_stream(net, slave_uart_slave_stream, X"77");
                check_stream(net, slave_uart_slave_stream, X"21");
                check_stream(net, slave_uart_slave_stream, X"0D");
                check_stream(net, slave_uart_slave_stream, X"0A");
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
        clk_freq_hz => (1 sec)/clk_period,
        baud_rate => baud_rate,
        icache_word_count_log2b => 9,
        dcache_word_count_log2b => 9,
        l2cache_words_per_line_log2b => l2cache_words_per_line_log2b,
        l2cache_total_line_count_log2b => 11,
        l2cache_bank_count_log2b => 3
    ) port map (
        JA_gpio(0) => si_sio0,
        JA_gpio(1) => so_sio1,
        JA_gpio(2) => sio2,
        JA_gpio(3) => hold_n_sio3,
        JB_gpio(3 downto 1) => cs_n,
        JB_gpio(0) => sck,
        general_gpio => general_gpio,
        clk => clk,
        master_rx => rx,
        master_tx => tx,
        slave_rx => slv_rx,
        slave_tx => slv_tx,
        spi_ss => spi_ss,
        spi_clk => spi_clk,
        spi_mosi => spi_mosi_miso,
        spi_miso => spi_mosi_miso
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
