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
    signal tx_queue_count_converted : std_logic_vector(15 downto 0);
    signal rx_queue_count_converted : std_logic_vector(15 downto 0);

    -- receive data
    signal receive_data : std_ulogic_vector(7 downto 0);
    signal receive_data_pop : boolean;
    signal receive_fifo_count : natural range 0 to 16;

    -- transmit data
    signal transmit_data : std_ulogic_vector(7 downto 0);
    signal transmit_data_push : boolean;
    signal transmit_fifo_count : natural range 0 to 16;

begin
    tx_queue_count_converted <= std_logic_vector(to_unsigned(transmit_fifo_count, tx_queue_count_converted'length));
    rx_queue_count_converted <= std_logic_vector(to_unsigned(receive_fifo_count, rx_queue_count_converted'length));
    slv2mst <= slv2mst_buf;

    bus_request_handler : process(clk)
       variable address : natural range 0 to 12;
       variable subAddress : natural range 0 to 3;
       variable data_byte : std_logic_vector(7 downto 0);
    begin
        if rising_edge(clk) then
            transmit_data_push <= false;
            receive_data_pop <= false;
            if reset then
                tx_reset_internal <= true;
                rx_reset_internal <= true;
                baud_clk_ticks <= (others => '0');
            elsif handle_bus_request then
                slv2mst_internal.readData <= (others => '0');
                slv2mst_internal.valid <= true;
                address := to_integer(unsigned(mst2slv.address(3 downto 0)));
                for i in 0 to bus_pkg.bus_bytes_per_word - 1 loop
                    data_byte := mst2slv.writeData(i*8 + 7 downto i*8);
                    if mst2slv.byteMask(i) = '1' then
                        if address + i = 0 and mst2slv.writeReady = '1' then
                            transmit_data_push <= true;
                            transmit_data <= data_byte;
                        end if;

                        if address + i = 1 then
                            if mst2slv.writeReady = '1' then
                                tx_reset_internal <= false when data_byte(0) = '1' else true;
                            end if;
                            slv2mst_internal.readData(i*8) <= '0' when tx_reset_internal else '1';
                            slv2mst_internal.readData(i*8 + 7 downto i*8 + 1) <= (others => '0');
                        end if;

                        if address + i = 2 and mst2slv.readReady = '1' then
                            receive_data_pop <= true;
                            slv2mst_internal.readData(i*8 + 7 downto i*8) <= receive_data;
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

    common_fifo_uart : entity work.common_fifo_uart
    generic map (
        receive_fifo_depth_log2b => 4,
        transmit_fifo_depth_log2b => 4
    ) port map (
        clk => clk,
        reset => reset,
        rx => rx,
        tx => tx,
        baud_clk_ticks => baud_clk_ticks,
        rx_enabled => not rx_reset_internal,
        tx_enabled => not tx_reset_internal,
        receive_data => receive_data,
        receive_data_pop => receive_data_pop,
        receive_fifo_count => receive_fifo_count,
        transmit_data => transmit_data,
        transmit_data_push => transmit_data_push,
        transmit_fifo_count => transmit_fifo_count
    );
end architecture;
