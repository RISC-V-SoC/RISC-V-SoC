library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;
use work.triple_23lc1024_pkg.all;

entity triple_23lc1024_controller is
    generic (
        system_clock_period : time;
        min_spi_clock_period : time := 50 ns;
        min_spi_cs_setup : time := 25 ns;
        min_spi_cs_hold : time := 50 ns
    );
    port (
        clk : in std_logic;
        rst : in boolean;

        spi_clk : out std_logic;
        spi_sio_in : in std_logic_vector(3 downto 0);
        spi_sio_out : out std_logic_vector(3 downto 0);
        spi_cs : out std_logic_vector(2 downto 0);

        mst2slv : in bus_mst2slv_type;
        slv2mst : out bus_slv2mst_type
    );
end triple_23lc1024_controller;

architecture behavioral of triple_23lc1024_controller is
    constant min_spi_clk_half_period : time := min_spi_clock_period / 2;
    constant spi_clk_half_period_ticks : natural := (min_spi_clk_half_period + (system_clock_period - 1 fs))/(system_clock_period);
    constant spi_cs_setup_ticks : natural := (min_spi_cs_setup + (system_clock_period - 1 fs))/system_clock_period;
    constant spi_cs_hold_ticks : natural := (min_spi_cs_hold + (system_clock_period - 1 fs)) / system_clock_period;

    -- Config specific signals
    signal config_done : boolean := false;
    signal spi_clk_config : std_logic;
    signal spi_sio_config : std_logic_vector(3 downto 0);
    signal spi_cs_config : std_logic_vector(2 downto 0);

    -- Read specific signals
    signal read_active : boolean := false;
    signal spi_clk_read : std_logic;
    signal spi_sio_read_in : std_logic_vector(3 downto 0);
    signal spi_sio_read_out : std_logic_vector(3 downto 0);
    signal cs_set_read  : std_logic;
    signal ready_read : boolean;
    signal valid_read : boolean;
    signal reading : boolean;

    -- Write specific signals
    signal write_active : boolean := false;
    signal spi_clk_write : std_logic;
    signal spi_sio_write_out : std_logic_vector(3 downto 0);
    signal cs_set_write  : std_logic;
    signal ready_write : boolean;
    signal valid_write : boolean;

    -- CS control signals
    signal spi_cs_internal : std_logic_vector(2 downto 0);
    signal cs_requested : cs_request_type;
    signal cs_request_writer : cs_request_type;
    signal cs_request_reader : cs_request_type;
    signal cs_state : std_logic;
    signal cs_set : std_logic;

    -- Bus parsing
    signal request_length : positive range 1 to bus_bytes_per_word;
    signal write_request : boolean;
    signal read_request : boolean;
    signal has_fault : boolean;
    signal cs_request : cs_request_type;
    signal write_data : bus_data_type;
    signal address : bus_address_type;
    signal virtual_write_burst : boolean;
begin

    slv2mst.fault <= '1' when has_fault else '0';
    slv2mst.valid <= valid_read or valid_write;

    ready_handling : process (write_request, read_request, config_done, read_active, write_active)
    begin
        ready_write <= false;
        ready_read <= false;
        if config_done then
            if not read_active then
                ready_write <= write_request;
            end if;

            if not write_active then
                ready_read <= read_request;
            end if;
        end if;
    end process;

    cs_control_handling : process(read_active, write_active, cs_set_read, cs_set_write, cs_request_reader, cs_request_writer)
    begin
        if read_active then
            cs_set <= cs_set_read;
            cs_requested <= cs_request_reader;
        elsif write_active then
            cs_set <= cs_set_write;
            cs_requested <= cs_request_writer;
        else
            cs_set <= '1';
            cs_requested <= request_none;
        end if;
    end process;

    cs_mux : process(config_done, spi_cs_config, spi_cs_internal)
    begin
        if not config_done then
            spi_cs <= spi_cs_config;
        else
            spi_cs <= spi_cs_internal;
        end if;
    end process;

    other_spi_mux : process(reading, config_done, read_active, write_active, spi_clk_config, spi_sio_config, spi_clk_read, spi_sio_read_out, spi_sio_in, spi_clk_write, spi_sio_write_out)
    begin
        spi_sio_read_in <= (others => 'X');
        if not config_done then
            spi_clk <= spi_clk_config;
            spi_sio_out <= spi_sio_config;
        elsif read_active then
            spi_clk <= spi_clk_read;
            if not reading then
                spi_sio_out <= spi_sio_read_out;
            else
                spi_sio_out <= (others => 'Z');
            end if;
            spi_sio_read_in <= spi_sio_in;
        elsif write_active then
            spi_clk <= spi_clk_write;
            spi_sio_out <= spi_sio_write_out;
        else
            spi_clk <= '0';
            spi_sio_out <= (others => 'Z');
        end if;
    end process;

    config : entity work.triple_23lc1024_config
    generic map (
        cs_wait_ticks => spi_cs_hold_ticks,
        spi_clk_half_period_ticks => spi_clk_half_period_ticks,
        spi_cs_hold_ticks => spi_cs_hold_ticks
    )
    port map (
        clk => clk,
        rst => rst,
        spi_clk => spi_clk_config,
        spi_sio => spi_sio_config,
        spi_cs => spi_cs_config,
        config_done => config_done
    );

    reader : entity work.triple_23lc1024_reader
    generic map (
        spi_clk_half_period_ticks => spi_clk_half_period_ticks
    )
    port map (
        clk => clk,
        rst => rst,
        spi_clk => spi_clk_read,
        spi_sio_in => spi_sio_read_in,
        spi_sio_out => spi_sio_read_out,
        cs_set => cs_set_read,
        cs_state => cs_state,
        ready => ready_read,
        valid => valid_read,
        active => read_active,
        fault => has_fault,
        reading => reading,
        address => address(16 downto 0),
        cs_request_in => cs_request,
        cs_request_out => cs_request_reader,
        request_length => request_length,
        read_data => slv2mst.readData,
        burst => mst2slv.burst
    );

    writer : entity work.triple_23lc1024_writer
    generic map (
        spi_clk_half_period_ticks => spi_clk_half_period_ticks
    )
    port map (
        clk => clk,
        rst => rst,
        spi_clk => spi_clk_write,
        spi_sio => spi_sio_write_out,
        cs_set => cs_set_write,
        cs_state => cs_state,
        ready => ready_write,
        valid => valid_write,
        active => write_active,
        fault => has_fault,
        address => address(16 downto 0),
        cs_request_in => cs_request,
        cs_request_out => cs_request_writer,
        request_length => request_length,
        write_data => write_data,
        burst => mst2slv.burst,
        virtual_burst => virtual_write_burst
    );

    parser : entity work.triple_23lc1024_bus_parser
    port map (
        clk => clk,
        rst => rst,
        mst2slv => mst2slv,
        transaction_valid => valid_write or valid_read,
        any_active => read_active or write_active,
        request_length => request_length,
        cs_request => cs_request,
        fault_data => slv2mst.faultData,
        has_fault => has_fault,
        write_data => write_data,
        address => address,
        read_request => read_request,
        write_request => write_request,
        virtual_write_burst => virtual_write_burst
    );

    cs_control : entity work.triple_23lc1024_cs_control
    generic map (
        spi_cs_setup_ticks => spi_cs_setup_ticks,
        spi_cs_hold_ticks => spi_cs_hold_ticks
    ) port map (
        clk => clk,
        cs_set => cs_set,
        cs_state => cs_state,
        cs_requested => cs_requested,
        spi_cs_n => spi_cs_internal
    );
end behavioral;
