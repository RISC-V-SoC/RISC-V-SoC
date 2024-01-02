library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;
use work.triple_23lc1024_pkg.all;

entity triple_23lc1024_reader is
    generic (
        spi_clk_half_period_ticks : natural
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        spi_clk : out std_logic;
        spi_sio_in : in std_logic_vector(3 downto 0);
        spi_sio_out : out std_logic_vector(3 downto 0);

        cs_set : out std_logic;
        cs_state : in std_logic;

        ready : in boolean;
        fault : in boolean;
        valid : out boolean;
        active : out boolean;
        reading : out boolean;

        request_length : in positive range 1 to bus_bytes_per_word;
        address : in std_logic_vector(16 downto 0);
        cs_request_in : in cs_request_type;
        cs_request_out : out cs_request_type;
        read_data : out bus_data_type;
        burst : in std_logic
    );
end triple_23lc1024_reader;

architecture behavioral of triple_23lc1024_reader is
    constant instructionRead : std_logic_vector(7 downto 0) := "00000011";

    signal half_period_timer_rst : std_logic := '1';
    signal half_period_timer_done : std_logic;
begin

    process(clk)
        constant max_count : natural := 20 + 2**(bus_data_width_log2b - 2) * 2;
        variable count : natural range 0 to max_count := 0;
        variable count_goal : natural range 20 to max_count := 20;
        variable cs_set_internal : std_logic := '1';
        variable read_data_internal : bus_data_type := (others => '0');
        variable transmitCommandAndAddress : std_logic_vector(31 downto 0) := (others => '0');
        variable transaction_complete : boolean := false;
        variable fault_latch : boolean := false;
        variable write_index : natural range 0 to bus_bytes_per_word * 2 := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                spi_clk <= '0';
                cs_set_internal := '1';
                valid <= false;
                active <= false;
                count := 0;
                transaction_complete := false;
                fault_latch := false;
            else
                if half_period_timer_done = '1' then
                    count := count + 1;
                end if;

                if count mod 2 = 0 then
                    spi_clk <= '0';
                else
                    spi_clk <= '1';
                end if;

                if cs_set_internal = '0' then
                    active <= true;
                else
                    active <= false;
                end if;

                if count = 0 then
                    reading <= false;
                    transaction_complete := false;
                    half_period_timer_rst <= '1';
                    valid <= false;
                    fault_latch := false;
                    if cs_set_internal = '1' and ready then
                        transmitCommandAndAddress := instructionRead & "0000000" & address;
                        cs_set_internal := '0';
                        cs_request_out <= cs_request_in;
                        count_goal := 20 + 4*request_length;
                    elsif cs_set_internal = '0' and cs_state = '0' then
                        spi_sio_out <= transmitCommandAndAddress(transmitCommandAndAddress'high downto transmitCommandAndAddress'high - 3);
                        half_period_timer_rst <= '0';
                    end if;
                end if;

                if count > 0 then
                    half_period_timer_rst <= '0';
                    cs_set_internal := '0';
                    valid <= false;
                    if fault then
                        fault_latch := true;
                    end if;
                end if;

                if count >= 1 and count <= 15 then
                    if count mod 2 = 0 and half_period_timer_done = '1' then
                        transmitCommandAndAddress := std_logic_vector(shift_left(unsigned(transmitCommandAndAddress), 4));
                    end if;
                    spi_sio_out <= transmitCommandAndAddress(transmitCommandAndAddress'high downto transmitCommandAndAddress'high - 3);
                end if;

                if count > 15 then
                    half_period_timer_rst <= '0';
                    cs_set_internal := '0';
                    valid <= false;
                end if;
                -- now we get a dummy byte. Also the point where we continue from when doing a burst.
                if count >= 16 and count <= 20 then
                    transaction_complete := false;
                    reading <= true;
                end if;

                -- Now the incoming data, which we read on the rising edge (= when count is uneven)
                if count > 20 and count <= count_goal - 1 then
                    if count mod 2 = 1 and half_period_timer_done = '1' then
                        write_index := (count - 20)/2;
                        read_data_internal(3 + write_index*4 downto write_index*4) := spi_sio_in;
                    end if;
                end if;

                if count = count_goal - 1 then
                    if not transaction_complete then
                        if fault_latch then
                            transaction_complete := true;
                            fault_latch := false;
                        elsif ready then
                            valid <= true;
                            transaction_complete := true;
                            if burst = '1' then
                                count := 19;
                            end if;
                        else
                            half_period_timer_rst <= '1';
                        end if;
                    end if;
                end if;

                if count = count_goal then
                    half_period_timer_rst <= '1';
                    cs_set_internal := '1';
                    transaction_complete := false;
                    active <= true;
                    if cs_state = '1' then
                        count := 0;
                    end if;
                end if;
            end if;
        end if;
        cs_set <= cs_set_internal;
        --read_data <= reorder_nibbles(read_data_internal);
        read_data <= read_data_internal;
    end process;

    half_period_timer : entity work.simple_multishot_timer
    generic map (
        match_val => spi_clk_half_period_ticks
    )
    port map (
        clk => clk,
        rst => half_period_timer_rst,
        done => half_period_timer_done
    );
end behavioral;

