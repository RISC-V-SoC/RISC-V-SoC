library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;
use ieee.math_real.all;

library work;
use work.bus_pkg.all;

entity main_file is
    generic (
        clk_freq_hz : natural;
        baud_rate : positive := 115200
    );
    port (
        JA_gpio : inout  STD_LOGIC_VECTOR (3 downto 0);
        JB_gpio : out  STD_LOGIC_VECTOR (3 downto 0);
        general_gpio : inout std_logic_vector(7 downto 0);
        clk : in  STD_LOGIC;
        global_reset : in std_logic;

        master_rx : in std_logic;
        master_tx : out std_logic;

        slave_rx : in std_logic;
        slave_tx : out std_logic;

        spi_ss : inout std_logic;
        spi_clk : out std_logic;
        spi_mosi : out std_logic;
        spi_miso : in std_logic
    );
end main_file;

architecture Behavioral of main_file is

    pure function create_address_map_entry (
        start_address : natural;
        mapping_size : natural
    ) return addr_range_and_mapping_type is
        variable end_address : natural;
        variable address_bits_required : natural;
    begin
        end_address := start_address + mapping_size - 1;
        address_bits_required := integer(ceil(log2(real(mapping_size)))) - 1;
        return address_range_and_map(
            low => std_logic_vector(to_unsigned(start_address, bus_address_type'length)),
            high => std_logic_vector(to_unsigned(end_address, bus_address_type'length)),
            mapping => bus_map_constant(bus_address_type'high - address_bits_required, '0') & bus_map_range(address_bits_required, 0)
        );
    end function;

    constant uartDeviceStartAddress : natural := 16#1000#;
    constant uartDeviceMappingSize : natural := 16#c#;

    constant staticDeviceInfoStartAddress : natural := 16#100c#;
    constant staticDeviceInfoMappingSize : natural := 16#4#;

    constant spiDeviceStartAddress : natural := 16#1010#;
    constant spiDeviceInfoMappingSize : natural := 16#c#;

    constant riscvControlStartAddress : natural := 16#2000#;
    constant riscvControlMappingSize : natural := 16#100#;

    constant gpioDeviceStartAddress : natural := 16#3000#;
    constant gpioDeviceMappingSize : natural := 16#12#;

    constant spiMemStartAddress : natural := 16#100000#;
    constant spiMemMappingSize : natural := 16#60000#;

    constant procStartAddress : bus_address_type := std_logic_vector(to_unsigned(spiMemStartAddress, bus_address_type'length));
    constant clk_period : time := (1 sec) / clk_freq_hz;

    constant address_map : addr_range_and_mapping_array := (
        create_address_map_entry(uartDeviceStartAddress, uartDeviceMappingSize),
        create_address_map_entry(staticDeviceInfoStartAddress, staticDeviceInfoMappingSize),
        create_address_map_entry(spiDeviceStartAddress, spiDeviceInfoMappingSize),
        create_address_map_entry(riscvControlStartAddress, riscvControlMappingSize),
        create_address_map_entry(gpioDeviceStartAddress, gpioDeviceMappingSize),
        create_address_map_entry(spiMemStartAddress, spiMemMappingSize)
    );

    signal rst          : STD_LOGIC;

    signal extMaster2arbiter : bus_mst2slv_type;
    signal arbiter2extMaster : bus_slv2mst_type;

    signal instructionFetch2arbiter : bus_mst2slv_type;
    signal arbiter2instructionFetch : bus_slv2mst_type;

    signal memory2arbiter : bus_mst2slv_type;
    signal arbiter2memory : bus_slv2mst_type;

    signal arbiter2demux : bus_mst2slv_type;
    signal demux2arbiter : bus_slv2mst_type;

    signal demux2uartSlave : bus_mst2slv_type;
    signal uartSlave2demux : bus_slv2mst_type;

    signal demux2staticInfo : bus_mst2slv_type;
    signal staticInfo2demux : bus_slv2mst_type;

    signal demux2spiDevice : bus_mst2slv_type;
    signal spiDevice2demux : bus_slv2mst_type;

    signal demux2control : bus_mst2slv_type;
    signal control2demux : bus_slv2mst_type;

    signal demux2gpio : bus_mst2slv_type;
    signal gpio2demux : bus_slv2mst_type;

    signal demux2spimem : bus_mst2slv_type;
    signal spimem2demux : bus_slv2mst_type;


    signal mem_spi_sio_out : std_logic_vector(3 downto 0);
    signal mem_spi_sio_in : std_logic_vector(3 downto 0);
    signal mem_spi_cs_n : std_logic_vector(2 downto 0);
    signal mem_spi_clk : std_logic;

begin

    rst <= global_reset;

    mem_spi_sio_in <= JA_gpio;
    JA_gpio <= mem_spi_sio_out;
    JB_gpio(3 downto 1) <= mem_spi_cs_n;
    JB_gpio(0) <= mem_spi_clk;

    externalMaster : entity work.uart_bus_master
    generic map (
        clk_period => clk_period,
        baud_rate => baud_rate
    ) port map (
        clk => clk,
        mst2slv => extMaster2arbiter,
        slv2mst => arbiter2extMaster,
        rx => master_rx,
        tx => master_tx
    );

    processor : entity work.riscv32_processor
    generic map (
        startAddress => procStartAddress,
        clk_period => clk_period,
        iCache_range => create_address_map_entry(spiMemStartAddress, spiMemMappingSize).addr_range,
        iCache_word_count_log2b => 8,
        dCache_range => create_address_map_entry(spiMemStartAddress, spiMemMappingSize).addr_range,
        dCache_word_count_log2b => 8
    ) port map (
        clk => clk,
        rst => rst,
        mst2control => demux2control,
        control2mst => control2demux,
        instructionFetch2slv => instructionFetch2arbiter,
        slv2instructionFetch => arbiter2instructionFetch,
        memory2slv => memory2arbiter,
        slv2memory => arbiter2memory
    );

    arbiter : entity work.bus_arbiter
    generic map (
        masterCount => 3
   ) port map (
        clk => clk,
        mst2arbiter(0) => instructionFetch2arbiter,
        mst2arbiter(1) => memory2arbiter,
        mst2arbiter(2) => extMaster2arbiter,
        arbiter2mst(0) => arbiter2instructionFetch,
        arbiter2mst(1) => arbiter2memory,
        arbiter2mst(2) => arbiter2extMaster,
        arbiter2slv => arbiter2demux,
        slv2arbiter => demux2arbiter
    );

    demux : entity work.bus_demux
    generic map (
        ADDRESS_MAP => address_map
    )
    port map (
        mst2demux => arbiter2demux,
        demux2mst => demux2arbiter,
        demux2slv(0) => demux2uartSlave,
        demux2slv(1) => demux2staticInfo,
        demux2slv(2) => demux2spiDevice,
        demux2slv(3) => demux2control,
        demux2slv(4) => demux2gpio,
        demux2slv(5) => demux2spimem,
        slv2demux(0) => uartSlave2demux,
        slv2demux(1) => staticInfo2demux,
        slv2demux(2) => spiDevice2demux,
        slv2demux(3) => control2demux,
        slv2demux(4) => gpio2demux,
        slv2demux(5) => spimem2demux
    );

    uart_bus_slave : entity work.uart_bus_slave
    port map (
        clk => clk,
        reset => rst = '1',
        rx => slave_rx,
        tx => slave_tx,
        mst2slv => demux2uartSlave,
        slv2mst => uartSlave2demux
    );

    static_soc_info : entity work.static_soc_info
    generic map (
        clk_freq_hz => clk_freq_hz
    ) port map (
        clk => clk,
        mst2slv => demux2staticInfo,
        slv2mst => staticInfo2demux
    );

    spi_master_device : entity work.spi_master_device
    port map (
        clk => clk,
        mosi => spi_mosi,
        miso => spi_miso,
        spi_clk => spi_clk,
        mst2slv => demux2spiDevice,
        slv2mst => spiDevice2demux
    );

    -- Control goes to processor

    gpio_controller : entity work.gpio_controller
    generic map (
        gpio_count => general_gpio'length + 1
    ) port map (
        clk => clk,
        gpio(general_gpio'high downto 0) => general_gpio,
        gpio(general_gpio'high + 1) => spi_ss,
        mst2slv => demux2gpio,
        slv2mst => gpio2demux
    );

    spimem : entity work.triple_23lc1024_controller
    generic map (
        system_clock_period => clk_period
    ) port map (
        clk => clk,
        rst => rst,
        spi_clk => mem_spi_clk,
        spi_sio_in => mem_spi_sio_in,
        spi_sio_out => mem_spi_sio_out,
        spi_cs => mem_spi_cs_n,
        mst2slv => demux2spimem,
        slv2mst => spimem2demux
    );

end Behavioral;
