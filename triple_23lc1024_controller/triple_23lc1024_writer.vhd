library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;
use work.triple_23lc1024_pkg.all;

entity triple_23lc1024_writer is
    generic (
        spi_clk_half_period_ticks : natural
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        spi_clk : out std_logic;
        spi_sio : out std_logic_vector(3 downto 0);

        cs_set : out std_logic;
        cs_state : in std_logic;

        ready : in boolean;
        fault : in boolean;
        valid : out boolean;
        active : out boolean;

        request_length : in positive range 1 to bus_bytes_per_word;
        address : in std_logic_vector(16 downto 0);
        cs_request_in : in cs_request_type;
        cs_request_out : out cs_request_type;
        write_data : in bus_data_type;
        burst : in std_logic;
        virtual_burst : in boolean
    );
end triple_23lc1024_writer;

architecture behavioral of triple_23lc1024_writer is
    constant instructionWrite : std_logic_vector(7 downto 0) := "00000010";

    signal half_period_timer_rst : std_logic := '1';
    signal half_period_timer_done : std_logic;

begin

    process(rst, clk)
        constant max_count : natural := 16 + 2**(bus_data_width_log2b - 2) * 2;
        variable count : natural range 0 to max_count := 0;
        variable count_goal : natural range 16 to max_count := 16;
        variable valid_internal : boolean := false;
        variable cs_set_internal : std_logic := '1';
        variable transmitData : bus_data_type := (others => 'X');
        variable burst_internal : std_logic := '0';
        variable transmitCommandAndAddress : std_logic_vector(31 downto 0) := (others => 'X');
        variable fault_latched : boolean := false;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                spi_clk <= '0';
                cs_set_internal := '1';
                valid_internal := false;
                count := 0;
                fault_latched := false;
            else
                if fault then
                    fault_latched := true;
                end if;

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
                    half_period_timer_rst <= '1';
                    valid_internal := false;
                    if ready and cs_set_internal = '1' then
                        fault_latched := false;
                        valid_internal := true;
                        transmitCommandAndAddress := instructionWrite & "0000000" & address;
                        transmitData := write_data;
                        burst_internal := burst;
                        cs_set_internal := '0';
                        cs_request_out <= cs_request_in;
                        count_goal := 16 + 4*request_length;
                    elsif cs_set_internal = '0' and cs_state = '0' then
                        spi_sio <= transmitCommandAndAddress(transmitCommandAndAddress'high downto transmitCommandAndAddress'high - 3);
                        half_period_timer_rst <= '0';
                    end if;
                end if;

                if count > 0 then
                    half_period_timer_rst <= '0';
                    cs_set_internal := '0';
                    valid_internal := false;
                end if;

                if count >= 1 and count < 15 then
                    if count mod 2 = 0 and half_period_timer_done = '1' then
                        transmitCommandAndAddress := std_logic_vector(shift_left(unsigned(transmitCommandAndAddress), 4));
                    end if;
                    spi_sio <= transmitCommandAndAddress(transmitCommandAndAddress'high downto transmitCommandAndAddress'high - 3);
                end if;

                if count = 16 then
                    spi_sio <= transmitData(3 downto 0);
                end if;

                if count > 16 and count < count_goal - 1 then
                    if count mod 2 = 0 and half_period_timer_done = '1' then
                        transmitData := std_logic_vector(shift_right(unsigned(transmitData), 4));
                    end if;
                    spi_sio <= transmitData(3 downto 0);
                end if;

                if count = count_goal - 1 then
                    if (burst_internal = '1' or virtual_burst) and not fault_latched then
                        if ready then
                            transmitData := write_data;
                            burst_internal := burst;
                            valid_internal := true;
                            count := 15;
                        else
                            half_period_timer_rst <= '1';
                        end if;
                    end if;
                end if;

                if count = count_goal then
                    half_period_timer_rst <= '1';
                    cs_set_internal := '1';
                    active <= true;
                    if cs_state = '1' then
                        count := 0;
                    end if;
                end if;
            end if;
        end if;
        cs_set <= cs_set_internal;
        valid <= valid_internal;
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
