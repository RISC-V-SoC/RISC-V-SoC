library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity triple_23lc1024_config is
    generic (
        cs_wait_ticks : natural;
        spi_clk_half_period_ticks : natural;
        spi_cs_hold_ticks : natural
    );
    port (
        clk : in std_logic;
        rst : in boolean;

        spi_clk : out std_logic;
        spi_sio : out std_logic_vector(3 downto 0);
        spi_cs : out std_logic_vector(2 downto 0);

        config_done : out boolean
    );
end triple_23lc1024_config;

architecture behavioral of triple_23lc1024_config is
    type state_type is (reset_state, initial_wait_state, drop_cs_state, rise_cs_state, transmission_state, configure_done_state);
    type active_operation_type is (quad_reset_operation, dual_reset_operation, spi_configure_operation, spi_enter_quad_operation);
    type transmission_state_type is (transmission_waiting_state, transmission_high_state,
        transmission_low_state, transmission_done_state);

    signal cur_state : state_type := reset_state;
    signal next_state : state_type := reset_state;

    signal cur_transmission_state : transmission_state_type := transmission_waiting_state;
    signal next_transmission_state : transmission_state_type := transmission_waiting_state;

    signal cur_active_operation : active_operation_type := quad_reset_operation;

    signal transmission_request : boolean := false;
    signal transmission_complete : boolean := false;

    signal cs_timer_rst : std_logic := '1';
    signal cs_timer_done : std_logic;

    signal hold_timer_rst : std_logic := '1';
    signal hold_timer_done : std_logic;

    signal half_period_timer_rst : std_logic := '1';
    signal half_period_timer_done : std_logic;

    constant reset_dual_quad_access_instruction : std_logic_vector(7 downto 0) := "11111111";
    constant configure_page_mode_instruction : std_logic_vector(15 downto 0) := "0000001010000000";
    constant enter_quad_access_instruction : std_logic_vector(7 downto 0) := "00011100";

    signal instruction_index : natural range 0 to configure_page_mode_instruction'high := 0;

    pure function get_next_operation (operation : active_operation_type) return active_operation_type is
        variable ret_val : active_operation_type := quad_reset_operation;
    begin
        case operation is
            when quad_reset_operation =>
                ret_val := dual_reset_operation;
            when dual_reset_operation =>
                ret_val := spi_configure_operation;
            when spi_configure_operation =>
                ret_val := spi_enter_quad_operation;
            when spi_enter_quad_operation =>
                ret_val := quad_reset_operation;
        end case;
        return ret_val;
    end function;

    pure function get_spi_sio(operation : active_operation_type;
                              index: natural)
                              return std_logic_vector is
        variable ret_val : std_logic_vector(3 downto 0) := (others => '0');
    begin
        case operation is
            when quad_reset_operation =>
                ret_val := reset_dual_quad_access_instruction(index*4 + 3 downto index*4);
            when dual_reset_operation =>
                -- ret_val(3) is the hold pin, active low
                ret_val(3) := '1';
                ret_val(2) := '0';
                ret_val(1 downto 0) := reset_dual_quad_access_instruction(index*2 + 1 downto index*2);
            when spi_configure_operation =>
                ret_val(3) := '1';
                ret_val(2) := '0';
                ret_val(1) := '0';
                ret_val(0) := configure_page_mode_instruction(index);
            when spi_enter_quad_operation =>
                ret_val(3) := '1';
                ret_val(2) := '0';
                ret_val(1) := '0';
                ret_val(0) := enter_quad_access_instruction(index);
        end case;
        return ret_val;
    end function;

    pure function is_transmission_complete(operation : active_operation_type;
                              index : natural)
                              return boolean is
        variable done : boolean := false;
    begin
        case operation is
            when quad_reset_operation =>
                done := index >= reset_dual_quad_access_instruction'high / 4;
            when dual_reset_operation =>
                done := index >= reset_dual_quad_access_instruction'high / 2;
            when spi_configure_operation =>
                done := index >= configure_page_mode_instruction'high;
            when spi_enter_quad_operation =>
                done := index >= enter_quad_access_instruction'high;
        end case;
        return done;
    end function;



begin

    sequential: process(clk)
    begin
        if rising_edge(clk) then
            if rst then
                cur_state <= reset_state;
                cur_transmission_state <= transmission_waiting_state;
                instruction_index <= 0;
                cur_active_operation <= quad_reset_operation;
            else
                cur_state <= next_state;
                cur_transmission_state <= next_transmission_state;

                if next_transmission_state = transmission_waiting_state or next_transmission_state = transmission_done_state then
                    instruction_index <= 0;
                elsif next_transmission_state = transmission_low_state and cur_transmission_state = transmission_high_state then
                    instruction_index <= instruction_index + 1;
                end if;

                if next_state = rise_cs_state and cur_state = transmission_state then
                    cur_active_operation <= get_next_operation(cur_active_operation);
                end if;
            end if;
        end if;
    end process;

    concurrent: process(cur_state, cur_transmission_state, instruction_index, cur_active_operation,
        cs_timer_done, half_period_timer_done, transmission_request, transmission_complete, hold_timer_done)
    begin
        -- Main state machine
        next_state <= cur_state;
        case cur_state is
            when reset_state =>
                config_done <= false;
                transmission_request <= false;
                cs_timer_rst <= '1';
                spi_cs <= (others => '1');
                next_state <= initial_wait_state;
            when initial_wait_state =>
                config_done <= false;
                transmission_request <= false;
                cs_timer_rst <= '0';
                spi_cs <= (others => '1');
                if cs_timer_done = '1' then
                    next_state <= drop_cs_state;
                end if;
            when drop_cs_state =>
                config_done <= false;
                transmission_request <= false;
                cs_timer_rst <= '0';
                spi_cs <= (others => '0');
                if cs_timer_done = '1' then
                    next_state <= transmission_state;
               end if;
           when transmission_state =>
                config_done <= false;
                transmission_request <= true;
                cs_timer_rst <= '1';
                spi_cs <= (others => '0');
                if transmission_complete then
                    next_state <= rise_cs_state;
                end if;
            when rise_cs_state =>
                config_done <= false;
                transmission_request <= false;
                cs_timer_rst <= '0';
                spi_cs <= (others => '1');
                if cs_timer_done = '1' then
                    if cur_active_operation = quad_reset_operation then
                        next_state <= configure_done_state;
                    else
                        next_state <= drop_cs_state;
                    end if;
               end if;
            when configure_done_state =>
                config_done <= true;
                transmission_request <= false;
                cs_timer_rst <= '1';
                spi_cs <= (others => '1');
                next_state <= configure_done_state;
        end case;
        -- Transmission state machine
        next_transmission_state <= cur_transmission_state;
        case cur_transmission_state is
            when transmission_waiting_state =>
                transmission_complete <= false;
                half_period_timer_rst <= '1';
                hold_timer_rst <= '1';
                spi_clk <= '0';
                spi_sio <= (others => '0');
                if transmission_request then
                    next_transmission_state <= transmission_low_state;
                end if;
            when transmission_low_state =>
                transmission_complete <= false;
                half_period_timer_rst <= '0';
                hold_timer_rst <= '1';
                spi_clk <= '0';
                spi_sio <= get_spi_sio(cur_active_operation, instruction_index);
                if half_period_timer_done = '1' then
                    next_transmission_state <= transmission_high_state;
                end if;
            when transmission_high_state =>
                transmission_complete <= false;
                half_period_timer_rst <= '0';
                hold_timer_rst <= '0';
                spi_clk <= '1';
                spi_sio <= get_spi_sio(cur_active_operation, instruction_index);
                if is_transmission_complete(cur_active_operation, instruction_index) then
                    if hold_timer_done = '1' then
                        next_transmission_state <= transmission_done_state;
                    end if;
                else
                    if half_period_timer_done = '1' then
                        next_transmission_state <= transmission_low_state;
                    end if;
                end if;
            when transmission_done_state =>
                transmission_complete <= true;
                half_period_timer_rst <= '1';
                hold_timer_rst <= '1';
                spi_clk <= '0';
                spi_sio <= (others => '0');
                if not transmission_request then
                    next_transmission_state <= transmission_waiting_state;
                end if;
            end case;
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

    cs_wait_timer : entity work.simple_multishot_timer
    generic map (
        match_val => cs_wait_ticks
    )
    port map (
        clk => clk,
        rst => cs_timer_rst,
        done => cs_timer_done
    );

    cs_hold_timer : entity work.simple_multishot_timer
    generic map (
        match_val => spi_cs_hold_ticks
    )
    port map (
        clk => clk,
        rst => hold_timer_rst,
        done => hold_timer_done
    );
end behavioral;
