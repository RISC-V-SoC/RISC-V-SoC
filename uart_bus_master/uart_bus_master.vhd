library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg;
use work.uart_bus_master_pkg;

entity uart_bus_master is
    generic (
        clk_period : time;
        baud_rate : positive
    );
    port (
        clk : in std_logic;

        rx : in std_logic;
        tx : out std_logic;

        mst2slv : out bus_pkg.bus_mst2slv_type;
        slv2mst : in bus_pkg.bus_slv2mst_type
    );
end entity;

architecture behaviourial of uart_bus_master is

    type command_type is (no_command, command_read_word, command_write_word, command_read_word_sequence, command_write_word_sequence);
    type state_type is (state_wait_for_command, state_command_response, state_wait_for_address, state_wait_for_count, state_read_word_from_uart, state_write_word_to_bus, state_read_word_from_bus, state_write_word_to_uart, state_finalize);

    signal tx_byte : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_data_ready : boolean := false;
    signal tx_busy : boolean;

    signal rx_byte : std_logic_vector(7 downto 0);
    signal rx_data_ready : boolean;

    -- tx_queue_signals
    signal tx_queue_data_in : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_queue_push_data : boolean := false;
    signal tx_queue_data_out : std_logic_vector(7 downto 0);
    signal tx_queue_pop_data : boolean := false;
    signal tx_queue_empty : boolean;
    signal tx_queue_full : boolean;

    -- rx_queue_signals
    signal rx_queue_data_in : std_logic_vector(7 downto 0);
    signal rx_queue_push_data : boolean := false;
    signal rx_queue_data_out : std_logic_vector(7 downto 0);
    signal rx_queue_pop_data : boolean := false;
    signal rx_queue_empty : boolean;

    signal address_to_bus : bus_pkg.bus_address_type;
    signal data_to_bus : bus_pkg.bus_data_type;
    signal data_from_bus : bus_pkg.bus_data_type;
    signal bus_do_read : boolean := false;
    signal bus_do_write : boolean := false;
    signal bus_finished : boolean := false;
    signal bus_fault : boolean := false;
    signal bus_last_fault : bus_pkg.bus_fault_type := bus_pkg.bus_fault_no_fault;

    signal sequence_size_buf : natural range 0 to 255;
    signal state_buf : state_type;

    pure function translateCommand(byte : std_logic_vector(7 downto 0))
                                   return command_type is
        variable ret_val : command_type := no_command;
    begin
        case byte is
            when uart_bus_master_pkg.COMMAND_READ_WORD =>
                ret_val := command_read_word;
            when uart_bus_master_pkg.COMMAND_WRITE_WORD =>
                ret_val := command_write_word;
            when uart_bus_master_pkg.COMMAND_READ_WORD_SEQUENCE =>
                ret_val := command_read_word_sequence;
            when uart_bus_master_pkg.COMMAND_WRITE_WORD_SEQUENCE =>
                ret_val := command_write_word_sequence;
            when others =>
                ret_val := no_command;
        end case;
        return ret_val;
    end function;

    procedure rx_queue_to_word(
        variable queue_wait_cycle : inout boolean;
        variable word_index_counter : inout natural range 0 to 3;
        signal word : out std_logic_vector(31 downto 0);
        signal byte : in std_logic_vector(7 downto 0);
        signal queue_empty : in boolean;
        signal queue_pop : out boolean;
        variable word_complete : out boolean) is
    begin
        word_complete := false;
        if queue_wait_cycle then
            queue_wait_cycle := false;
        elsif not queue_empty then
            word(word_index_counter*8 + 7 downto word_index_counter*8) <= byte;
            queue_pop <= true;
            queue_wait_cycle := true;
            if word_index_counter = 3 then
                word_complete := true;
                word_index_counter := 0;
            else
                word_index_counter := word_index_counter + 1;
                word_complete := false;
            end if;
        end if;
    end procedure;

    procedure rx_queue_to_byte(
        variable queue_wait_cycle : inout boolean;
        variable byte_out : out std_logic_vector(7 downto 0);
        signal byte_in : in std_logic_vector(7 downto 0);
        signal queue_empty : in boolean;
        signal queue_pop : out boolean;
        variable word_complete : out boolean) is
    begin
        word_complete := false;
        if queue_wait_cycle then
            queue_wait_cycle := false;
        elsif not queue_empty then
            byte_out := byte_in;
            queue_pop <= true;
            queue_wait_cycle := true;
            word_complete := true;
        end if;
    end procedure;

    procedure word_to_tx_queue(
        variable queue_wait_cycle : inout boolean;
        variable word_index_counter : inout natural range 0 to 3;
        signal word : in std_logic_vector(31 downto 0);
        signal byte : out std_logic_vector(7 downto 0);
        signal queue_full : in boolean;
        signal queue_push : out boolean;
        variable word_complete : out boolean) is
    begin
        word_complete := false;
        if queue_wait_cycle then
            queue_wait_cycle := false;
        elsif not queue_full then
            byte <= word(word_index_counter*8 + 7 downto word_index_counter*8);
            queue_push <= true;
            queue_wait_cycle := true;
            if word_index_counter = 3 then
                word_complete := true;
                word_index_counter := 0;
            else
                word_index_counter := word_index_counter + 1;
                word_complete := false;
            end if;
        end if;
    end procedure;

    procedure byte_to_tx_queue(
        variable queue_wait_cycle : inout boolean;
        signal byte_out : out std_logic_vector(7 downto 0);
        variable byte_in : in std_logic_vector(7 downto 0);
        signal queue_full : in boolean;
        signal queue_push : out boolean;
    variable word_complete : out boolean) is
    begin
        word_complete := false;
        if queue_wait_cycle then
            queue_wait_cycle := false;
        elsif not queue_full then
            byte_out <= byte_in;
            queue_push <= true;
            queue_wait_cycle := true;
            word_complete := true;
        end if;
    end procedure;
begin
    fsm : process(clk)
        variable cur_state : state_type := state_wait_for_command;
        variable next_state : state_type := state_wait_for_command;

        variable command : command_type := no_command;
        variable word_index_counter : natural range 0 to 3 := 0;
        variable sequence_size : natural range 0 to 255;
        variable queue_wait_cycle : boolean := false;
        variable word_complete : boolean := false;
        variable byte_out : std_logic_vector(7 downto 0);

        variable bus_fault_occured : boolean := false;
        variable first_bus_fault : bus_pkg.bus_fault_type;
    begin
        if rising_edge(clk) then
            rx_queue_pop_data <= false;
            tx_queue_push_data <= false;
            bus_do_read <= false;
            bus_do_write <= false;
            cur_state := next_state;
            case cur_state is
                when state_wait_for_command =>
                    rx_queue_to_byte(queue_wait_cycle, byte_out, rx_queue_data_out, rx_queue_empty, rx_queue_pop_data,
                                     word_complete);
                    if word_complete then
                        command := translateCommand(byte_out);
                        next_state := state_command_response;
                    end if;
                when state_command_response =>
                    if command = no_command then
                        byte_out := uart_bus_master_pkg.ERROR_UNKOWN_COMMAND;
                    else
                        byte_out := uart_bus_master_pkg.ERROR_NO_ERROR;
                    end if;
                    byte_to_tx_queue(queue_wait_cycle, tx_queue_data_in, byte_out, tx_queue_full, tx_queue_push_data,
                                     word_complete);
                    if word_complete then
                        if command = no_command then
                            next_state := state_wait_for_command;
                        else
                            next_state := state_wait_for_address;
                        end if;
                    end if;
                when state_wait_for_address =>
                    rx_queue_to_word(queue_wait_cycle, word_index_counter, address_to_bus, rx_queue_data_out,
                                     rx_queue_empty, rx_queue_pop_data, word_complete);

                    if word_complete then
                        sequence_size := 0;
                        if command = command_read_word then
                            next_state := state_read_word_from_bus;
                        elsif command = command_write_word then
                            next_state := state_read_word_from_uart;
                        else
                            next_state := state_wait_for_count;
                        end if;
                    end if;
                when state_wait_for_count =>
                    rx_queue_to_byte(queue_wait_cycle, byte_out, rx_queue_data_out, rx_queue_empty, rx_queue_pop_data,
                                     word_complete);
                    if word_complete then
                        sequence_size := to_integer(unsigned(byte_out));
                        if command = command_write_word_sequence then
                            next_state := state_read_word_from_uart;
                        else
                            next_state := state_read_word_from_bus;
                        end if;
                    end if;
                when state_read_word_from_bus =>
                    if bus_finished then
                        if not bus_fault_occured and bus_fault then
                            first_bus_fault := bus_last_fault;
                            bus_fault_occured := true;
                        end if;
                        next_state := state_write_word_to_uart;
                    else
                        bus_do_read <= true;
                    end if;
                when state_write_word_to_uart =>
                    word_to_tx_queue(queue_wait_cycle, word_index_counter, data_from_bus, tx_queue_data_in, tx_queue_full,
                                     tx_queue_push_data, word_complete);
                    if word_complete then
                        if sequence_size = 0 then
                            next_state := state_finalize;
                        else
                            sequence_size := sequence_size - 1;
                            address_to_bus <= std_logic_vector(unsigned(address_to_bus) + 4);
                            next_state := state_read_word_from_bus;
                        end if;
                    end if;
                when state_read_word_from_uart =>
                    rx_queue_to_word(queue_wait_cycle, word_index_counter, data_to_bus, rx_queue_data_out,
                                     rx_queue_empty, rx_queue_pop_data, word_complete);
                    if word_complete then
                        next_state := state_write_word_to_bus;
                    end if;
                when state_write_word_to_bus =>
                    bus_do_write <= true;
                    if bus_finished then
                        bus_do_write <= false;
                        if not bus_fault_occured and bus_fault then
                            first_bus_fault := bus_last_fault;
                            bus_fault_occured := true;
                        end if;
                        if sequence_size = 0 then
                            next_state := state_finalize;
                        else
                            sequence_size := sequence_size - 1;
                            address_to_bus <= std_logic_vector(unsigned(address_to_bus) + 4);
                            next_state := state_read_word_from_uart;
                        end if;
                    end if;
                when state_finalize =>
                    if bus_fault_occured then
                        byte_out := first_bus_fault & uart_bus_master_pkg.ERROR_BUS(3 downto 0);
                    else
                        byte_out := uart_bus_master_pkg.ERROR_NO_ERROR;
                    end if;
                    byte_to_tx_queue(queue_wait_cycle, tx_queue_data_in, byte_out, tx_queue_full, tx_queue_push_data,
                                     word_complete);
                    if word_complete then
                        next_state := state_wait_for_command;
                        bus_fault_occured := false;
                    end if;
                when others =>
                    next_state := cur_state;
            end case;
        end if;
        sequence_size_buf <= sequence_size;
        state_buf <= next_state;
    end process;

    bus_handling : process(clk)
        variable mst2slv_buf : bus_pkg.bus_mst2slv_type := bus_pkg.BUS_MST2SLV_IDLE;
    begin
        if rising_edge(clk) then
            if bus_finished then
                bus_finished <= false;
            elsif bus_pkg.any_transaction(mst2slv_buf, slv2mst) then
                data_from_bus <= slv2mst.readData;
                if bus_pkg.fault_transaction(mst2slv_buf, slv2mst) then
                    bus_last_fault <= slv2mst.faultData;
                    bus_fault <= true;
                else
                    bus_fault <= false;
                end if;
                mst2slv_buf := bus_pkg.BUS_MST2SLV_IDLE;
                bus_finished <= true;
            elsif bus_pkg.bus_requesting(mst2slv_buf) then
                -- pass
            elsif bus_do_read then
                mst2slv_buf := bus_pkg.bus_mst2slv_read(address_to_bus);
            elsif bus_do_write then
                mst2slv_buf := bus_pkg.bus_mst2slv_write(address_to_bus, data_to_bus);
            end if;
        end if;
        mst2slv <= mst2slv_buf;
    end process;

    rx_to_queue_handling : process(clk)
    begin
        if rising_edge(clk) then
            rx_queue_data_in <= rx_byte;
            if rx_data_ready then
                rx_queue_push_data <= true;
            else
                rx_queue_push_data <= false;
            end if;
        end if;
    end process;

    tx_from_queue_handling : process(clk)
        variable process_active : boolean := false;
    begin
        if rising_edge(clk) then
            tx_byte <= tx_queue_data_out;
            tx_data_ready <= false;
            tx_queue_pop_data <= false;
            if process_active and tx_busy then
                process_active := false;
                elsif not process_active and not tx_queue_empty and not tx_busy then
                tx_data_ready <= true;
                tx_queue_pop_data <= true;
                process_active := true;
            end if;
        end if;
    end process;

    bus_master_tx : entity work.uart_bus_master_tx
    generic map (
        clk_period => clk_period,
        baud_rate => baud_rate
    ) port map (
        clk => clk,
        rst => '0',
        tx => tx,
        transmit_byte => tx_byte,
        data_ready => tx_data_ready,
        busy => tx_busy
    );

    bus_master_rx : entity work.uart_bus_master_rx
    generic map (
        clk_period => clk_period,
        baud_rate => baud_rate
    ) port map (
        clk => clk,
        rst => '0',
        rx => rx,
        receive_byte => rx_byte,
        data_ready => rx_data_ready
    );

    tx_queue : entity work.generic_fifo
    generic map (
        depth_log2b => 4,
        word_size_log2b => 3
    )
    port map (
        clk => clk,
        reset => false,
        empty => tx_queue_empty,
        full => tx_queue_full,
        data_in => tx_queue_data_in,
        push_data => tx_queue_push_data,
        data_out => tx_queue_data_out,
        pop_data => tx_queue_pop_data
    );

    rx_queue : entity work.generic_fifo
    generic map (
        depth_log2b => 4,
        word_size_log2b => 3
    )
    port map (
        clk => clk,
        reset => false,
        empty => rx_queue_empty,
        data_in => rx_queue_data_in,
        push_data => rx_queue_push_data,
        data_out => rx_queue_data_out,
        pop_data => rx_queue_pop_data
    );


end architecture;
