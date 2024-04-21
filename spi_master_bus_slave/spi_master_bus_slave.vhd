library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.bus_pkg;

entity spi_master_bus_slave is
    port (
        clk : in std_logic;
        mosi : out std_logic;
        miso : in std_logic;
        spi_clk : out std_logic;

        mst2slv : in bus_pkg.bus_mst2slv_type;
        slv2mst : out bus_pkg.bus_slv2mst_type
    );
end entity;

architecture behavioral of spi_master_bus_slave is
    -- Address 0, bit 0: Enable
    -- Address 0, bit 1: CPOL, 0 means spi_clk low on idle, 1 means spi clk high on idle
    -- Address 0, bit 2: CPHA, 0 means data sampled on rising edge, 1 means data samples on falling edge. Data is shifted on opposite edge
    -- Address 0, bits 3 - 7: Reserved.
    -- Address 1: TX data, WO.
    -- Address 2: RX data, RO.
    -- Address 3: Reserved.
    -- Address 4-5: TX queue count.
    -- Address 6-7: RX queue count.
    -- Address 8-11: Clock divider, RW when disabled, RO when enabled.
    signal slv2mst_buf : bus_pkg.bus_slv2mst_type := bus_pkg.BUS_SLV2MST_IDLE;

    signal enabled : boolean := false;
    signal spi_clk_high_on_idle : boolean := false;
    signal sample_on_falling_edge : boolean := false;

    signal baud_clk_ticks : unsigned(31 downto 0) := (others => '0');

    signal spi_clk_buf : std_logic := '0';
    signal spi_clk_enable : boolean;
    signal spi_clk_timer_done : boolean;

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
    spi_clk <= spi_clk_buf;

    bus_handling : process(clk)
        variable slv2mst_tmp : bus_pkg.bus_slv2mst_type := bus_pkg.BUS_SLV2MST_IDLE;
        variable address : natural range 0 to 12;
        variable subAddress : natural range 0 to 3;
        variable byte_in : std_logic_vector(7 downto 0);
        variable byte_out : std_logic_vector(7 downto 0);
    begin
        if rising_edge(clk) then
            tx_queue_push_data <= false;
            rx_queue_pop_data <= false;
            if bus_pkg.any_transaction(mst2slv, slv2mst_buf) then
                slv2mst_buf <= bus_pkg.BUS_SLV2MST_IDLE;
                slv2mst_tmp := bus_pkg.BUS_SLV2MST_IDLE;
            elsif slv2mst_tmp.valid then
                slv2mst_buf <= slv2mst_tmp;
            elsif bus_pkg.bus_requesting(mst2slv) then
                slv2mst_tmp.valid := true;
                address := to_integer(unsigned(mst2slv.address(3 downto 0)));
                for i in 0 to bus_pkg.bus_bytes_per_word - 1 loop

                    byte_in := mst2slv.writeData(i*8 + 7 downto i*8);

                    if mst2slv.byteMask(i) = '0' then
                        next;
                    end if;

                    if address + i = 0 then
                        byte_out(0) := '1' when enabled else '0';
                        byte_out(1) := '1' when spi_clk_high_on_idle else '0';
                        byte_out(2) := '1' when sample_on_falling_edge else '0';
                        if mst2slv.writeReady = '1' then
                            enabled <= byte_in(0) = '1';
                            if not enabled then
                                spi_clk_high_on_idle <= byte_in(1) = '1';
                                sample_on_falling_edge <= byte_in(2) = '1';
                            end if;
                        end if;
                    end if;

                    if address + i = 1 and mst2slv.writeReady = '1' then
                        tx_queue_push_data <= true;
                        tx_queue_data_in <= byte_in;
                    end if;

                    if address + i = 2 and mst2slv.writeReady = '0' then
                        rx_queue_pop_data <= true;
                        byte_out := rx_queue_data_out;
                    end if;

                    if address + i >= 4 and address + i <= 5 then
                        subAddress := address + i - 4;
                        byte_out := tx_queue_count_converted(subAddress * 8 +7 downto subAddress * 8);
                    end if;

                    if address + i >= 6 and address + i <= 7 then
                        subAddress := address + i - 6;
                        byte_out := rx_queue_count_converted(subAddress * 8 +7 downto subAddress * 8);
                    end if;

                    if address + i >= 8 and address + i < 12 then
                        subAddress := address + i - 8;
                        if mst2slv.writeReady = '1' and not enabled then
                            baud_clk_ticks(subAddress * 8 + 7 downto subAddress*8) <= unsigned(byte_in);
                        end if;
                        byte_out := std_logic_vector(baud_clk_ticks(subAddress * 8 + 7 downto subAddress*8));
                    end if;

                    slv2mst_tmp.readData(i*8 + 7 downto i*8) := byte_out;

                end loop;
            end if;
        end if;
    end process;

    spi_clk_gen : process(clk, spi_clk_high_on_idle)
        variable spi_clk_internal : std_logic := '0';
    begin
        if rising_edge(clk) then
            if not enabled then
                spi_clk_internal := '0';
            elsif spi_clk_timer_done then
                spi_clk_internal := not spi_clk_internal;
            end if;
        end if;
        if spi_clk_high_on_idle then
            spi_clk_buf <= not spi_clk_internal;
        else
            spi_clk_buf <= spi_clk_internal;
        end if;
    end process;


    tx_side : entity work.spi_master_bus_slave_master
    port map (
        clk => clk,
        mosi => mosi,
        spi_clk => spi_clk_buf,
        is_enabled => enabled,
        shift_on_rising_edge => sample_on_falling_edge,
        spi_clk_enable => spi_clk_enable,
        data_in => tx_queue_data_out,
        data_available => not tx_queue_empty,
        data_pop => tx_queue_pop_data
    );

    tx_queue : entity work.generic_fifo
    generic map (
        depth_log2b => 4,
        word_size_log2b => 3
    )
    port map (
        clk => clk,
        reset => not enabled,
        empty => tx_queue_empty,
        data_in => tx_queue_data_in,
        push_data => tx_queue_push_data,
        data_out => tx_queue_data_out,
        pop_data => tx_queue_pop_data,
        count => tx_queue_count
    );

    spi_clk_timer : entity work.configurable_multishot_timer
    port map (
        clk => clk,
        reset => not spi_clk_enable,
        done => spi_clk_timer_done,
        target_value => '0' & baud_clk_ticks(31 downto 1)
    );

    rx_side : entity work.spi_master_bus_slave_slave
    port map (
        clk => clk,
        miso => miso,
        spi_clk => spi_clk_buf,
        is_enabled => enabled,
        shift_on_rising_edge => sample_on_falling_edge,
        data_out => rx_queue_data_in,
        data_ready => rx_queue_push_data
    );

    rx_queue : entity work.generic_fifo
    generic map (
        depth_log2b => 4,
        word_size_log2b => 3
    )
    port map (
        clk => clk,
        reset => not enabled,
        empty => rx_queue_empty,
        data_in => rx_queue_data_in,
        push_data => rx_queue_push_data,
        data_out => rx_queue_data_out,
        pop_data => rx_queue_pop_data,
        count => rx_queue_count
    );
end architecture;
