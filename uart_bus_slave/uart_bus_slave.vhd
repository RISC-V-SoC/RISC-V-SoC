library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.bus_pkg;

entity uart_bus_slave is
    port (
        clk : in std_logic;
        reset : in boolean;

        rx : in std_logic;
        tx : out std_logic;

        mst2slv : in bus_pkg.bus_mst2slv_type;
        slv2mst : out bus_pkg.bus_slv2mst_type
    );
end entity;

architecture behavioral of uart_bus_slave is
    -- First register, 4 byte, contains tx_data_in (wo), tx_enable (rw, single bit, lsb), data_out (ro), rx_enable(rw, single bit, lsb)
    -- Second register, 4 byte, contains tx_queue_count (16 bit, ro), rx_queue_size (16 bit, ro)
    -- Third register, 4 byte, contains baud_divider, 31 bit, unsigned value
    signal tx_reset_internal : boolean := true;
    signal rx_reset_internal : boolean := true;
    signal baud_clk_ticks : unsigned(31 downto 0);
    signal slv2mst_buf : bus_pkg.bus_slv2mst_type := bus_pkg.BUS_SLV2MST_IDLE;
    signal slv2mst_internal : bus_pkg.bus_slv2mst_type := bus_pkg.BUS_SLV2MST_IDLE;
    signal handle_bus_request : boolean := false;

    -- tx_queue_signals
    signal tx_queue_data_in : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_queue_push_data : boolean := false;
    signal tx_queue_data_out : std_logic_vector(7 downto 0);
    signal tx_queue_pop_data : boolean;
    signal tx_queue_empty : boolean;
    signal tx_queue_count : natural range 0 to 16;
    signal tx_queue_count_converted : std_logic_vector(15 downto 0);

    -- rx_queue_signals
    signal rx_queue_data_in : std_logic_vector(7 downto 0);
    signal rx_queue_push_data : boolean;
    signal rx_queue_data_out : std_logic_vector(7 downto 0);
    signal rx_queue_pop_data : boolean := false;
    signal rx_queue_empty : boolean;
    signal rx_queue_count : natural range 0 to 16;
    signal rx_queue_count_converted : std_logic_vector(15 downto 0);
begin

    tx_queue_count_converted <= std_logic_vector(to_unsigned(tx_queue_count, tx_queue_count_converted'length));
    rx_queue_count_converted <= std_logic_vector(to_unsigned(rx_queue_count, rx_queue_count_converted'length));
    slv2mst <= slv2mst_buf;

    bus_request_handler : process(clk)
       variable address : natural range 0 to 12;
       variable subAddress : natural range 0 to 3;
       variable data_byte : std_logic_vector(7 downto 0);
    begin
        if rising_edge(clk) then
            tx_queue_push_data <= false;
            rx_queue_pop_data <= false;
            if reset then
                tx_reset_internal <= true;
                rx_reset_internal <= true;
            elsif handle_bus_request then
                slv2mst_internal.valid <= true;
                address := to_integer(unsigned(mst2slv.address(3 downto 0)));
                for i in 0 to bus_pkg.bus_bytes_per_word - 1 loop
                    data_byte := mst2slv.writeData(i*8 + 7 downto i*8);
                    if mst2slv.byteMask(i) = '1' then
                        if address + i = 0 and mst2slv.writeReady = '1' then
                            tx_queue_push_data <= true;
                            tx_queue_data_in <= data_byte;
                        end if;

                        if address + i = 1 then
                            if mst2slv.writeReady = '1' then
                                tx_reset_internal <= false when data_byte(0) = '1' else true;
                            end if;
                            slv2mst_internal.readData(i*8) <= '0' when tx_reset_internal else '1';
                            slv2mst_internal.readData(i*8 + 7 downto i*8 + 1) <= (others => '0');
                        end if;

                        if address + i = 2 and mst2slv.readReady = '1' then
                            rx_queue_pop_data <= true;
                            slv2mst_internal.readData(i*8 + 7 downto i*8) <= rx_queue_data_out;
                        end if;

                        if address + i = 3 then
                            if mst2slv.writeReady = '1' then
                                rx_reset_internal <= false when data_byte(0) = '1' else true;
                            end if;
                            slv2mst_internal.readData(i*8) <= '0' when rx_reset_internal else '1';
                            slv2mst_internal.readData(i*8 + 7 downto i*8 + 1) <= (others => '0');
                        end if;

                        if address + i >= 4 and address + i < 6 then
                            subAddress := address + i - 4;
                            slv2mst_internal.readData(i*8 + 7 downto i*8) <= tx_queue_count_converted(subAddress*8 + 7 downto subAddress*8);
                        end if;

                        if address + i >= 6 and address + i < 8 then
                            subAddress := address + i - 6;
                            slv2mst_internal.readData(i*8 + 7 downto i*8) <= rx_queue_count_converted(subAddress*8 + 7 downto subAddress*8);
                        end if;

                        if address + i >= 8 and address + i < 12 then
                            subAddress := address + i - 8;
                            if mst2slv.writeReady = '1' then
                                baud_clk_ticks(subAddress * 8 + 7 downto subAddress*8) <= unsigned(data_byte);
                            end if;
                            slv2mst_internal.readData(i*8 + 7 downto i*8) <= std_logic_vector(baud_clk_ticks(subAddress * 8 + 7 downto subAddress*8));
                        end if;
                    end if;
                end loop;
            end if;
        end if;
    end process;

    process(clk)
        variable transaction_in_progress : boolean := false;
        variable transaction_response_ready : boolean := false;
    begin
        if rising_edge(clk) then
            if reset then
                transaction_in_progress := false;
                transaction_response_ready := false;
                handle_bus_request <= false;
            elsif bus_pkg.any_transaction(mst2slv, slv2mst_buf) then
                transaction_in_progress := false;
                transaction_response_ready := false;
                slv2mst_buf <= bus_pkg.BUS_SLV2MST_IDLE;
            elsif transaction_in_progress and transaction_response_ready then
                slv2mst_buf <= slv2mst_internal;
            elsif transaction_in_progress then
                handle_bus_request <= false;
                transaction_response_ready := true;
            elsif bus_pkg.bus_requesting(mst2slv) then
                transaction_in_progress := true;
                handle_bus_request <= true;
            end if;
        end if;
    end process;

    uart_bus_slave_writer : entity work.uart_bus_slave_writer
    port map (
        clk => clk,
        reset => tx_reset_internal,
        half_baud_clk_ticks => '0' & baud_clk_ticks(31 downto 1),
        tx => tx,
        data_in => tx_queue_data_out,
        data_available => not tx_queue_empty,
        data_pop => tx_queue_pop_data
    );

    uart_bus_slave_reader : entity work.uart_bus_slave_reader
    port map (
        clk => clk,
        reset => rx_reset_internal,
        half_baud_clk_ticks => '0' & baud_clk_ticks(31 downto 1),
        rx => rx,
        data_out => rx_queue_data_in,
        data_ready => rx_queue_push_data
    );

    tx_queue : entity work.generic_fifo
    generic map (
        depth_log2b => 4,
        word_size_log2b => 3
    )
    port map (
        clk => clk,
        reset => tx_reset_internal,
        empty => tx_queue_empty,
        data_in => tx_queue_data_in,
        push_data => tx_queue_push_data,
        data_out => tx_queue_data_out,
        pop_data => tx_queue_pop_data,
        count => tx_queue_count
    );

    rx_queue : entity work.generic_fifo
    generic map (
        depth_log2b => 4,
        word_size_log2b => 3
    )
    port map (
        clk => clk,
        reset => rx_reset_internal,
        empty => rx_queue_empty,
        data_in => rx_queue_data_in,
        push_data => rx_queue_push_data,
        data_out => rx_queue_data_out,
        pop_data => rx_queue_pop_data,
        count => rx_queue_count
    );
end architecture;
