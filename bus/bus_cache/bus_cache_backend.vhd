library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;

entity bus_cache_backend is
    generic (
        words_per_line_log2b : natural range 0 to natural'high
    );
    port (
        clk : in std_logic;
        rst : in boolean;

        backend2slv : out bus_mst2slv_type;
        slv2backend : in bus_slv2mst_type;

        word_index : out natural range 0 to 2**words_per_line_log2b - 1;

        do_write : in boolean;
        write_address : in bus_address_type;
        write_data : in bus_data_type;

        do_read : in boolean;
        read_word_retrieved : out boolean;
        read_address : in bus_address_type;
        read_data : out bus_data_type;

        line_complete : out boolean;
        bus_fault : out boolean;
        bus_fault_data : out bus_fault_type
    );
end entity;

architecture behaviourial of bus_cache_backend is
    type state_type is (idle, write_word_retrieve, write_send, read_word_store, read_send, transaction_completing, transaction_fault);

    constant words_per_line : natural := 2**words_per_line_log2b;
    constant word_index_max : natural := words_per_line - 1;

    signal current_word_index : natural range 0 to words_per_line - 1 := 0;
    signal backend2slv_buf : bus_mst2slv_type;
    signal cur_state : state_type := idle;
    signal next_state : state_type := idle;
    signal actual_write_address : bus_address_type;
    signal actual_read_address : bus_address_type;
    signal read_word_retrieved_buf : boolean;

    signal write_address_buf : bus_address_type;
    signal read_address_buf : bus_address_type;
    signal write_address_to_send : bus_address_type;
    signal buffered_write_index : natural range 0 to words_per_line - 1;
begin
    backend2slv <= backend2slv_buf;
    backend2slv_buf.byteMask <= (others => '1');
    word_index <= current_word_index;
    read_word_retrieved <= read_word_retrieved_buf;

    determine_actual_address : process(current_word_index, write_address_buf, read_address_buf)
        variable base_address : unsigned(backend2slv_buf.address'range);
        variable sub_address : unsigned(backend2slv_buf.address'range);
    begin
        sub_address := unsigned(to_unsigned(current_word_index * bus_bytes_per_word, sub_address'length));

        base_address := unsigned(write_address_buf);
        actual_write_address <= std_logic_vector(base_address + sub_address);

        base_address := unsigned(read_address_buf);
        actual_read_address <= std_logic_vector(base_address + sub_address);
    end process;

    data_vault : process(clk)
    begin
        if rising_edge(clk) then
            if cur_state = write_word_retrieve or cur_state = idle then
                backend2slv_buf.writeData <= write_data;
                write_address_to_send <= actual_write_address;
                buffered_write_index <= current_word_index;
            end if;
            read_data <= slv2backend.readData;
            if fault_transaction(backend2slv_buf, slv2backend) then
                bus_fault_data <= slv2backend.faultData;
            end if;
            write_address_buf <= write_address;
            read_address_buf <= read_address;
        end if;
    end process;

    word_index_counter : process(clk)
    begin
        if rising_edge(clk) then
            if rst then
                current_word_index <= 0;
            elsif fault_transaction(backend2slv_buf, slv2backend) then
                current_word_index <= 0;
            elsif read_word_retrieved_buf then
                if current_word_index < word_index_max then
                    current_word_index <= current_word_index + 1;
                else
                    current_word_index <= 0;
                end if;
            elsif cur_state = write_word_retrieve then
                if current_word_index < word_index_max then
                    current_word_index <= current_word_index + 1;
                else
                    current_word_index <= 0;
                end if;
            end if;
        end if;
    end process;

    fsm_sequential : process(clk)
    begin
        if rising_edge(clk) then
            if rst then
                cur_state <= idle;
            else
                cur_state <= next_state;
            end if;
        end if;
    end process;

    fsm_combinatorial : process(cur_state, slv2backend, do_write, do_read, current_word_index, actual_write_address, actual_read_address, write_address_to_send, buffered_write_index)
    begin
        next_state <= cur_state;
        case cur_state is
            when idle =>
                backend2slv_buf.address <= (others => '-');
                backend2slv_buf.readReady <= '0';
                backend2slv_buf.writeReady <= '0';
                backend2slv_buf.burst <= '0';
                backend2slv_buf.address <= (others => '-');
                read_word_retrieved_buf <= false;
                line_complete <= false;
                bus_fault <= false;
                if do_write then
                    next_state <= write_word_retrieve;
                elsif do_read then
                    next_state <= read_send;
                end if;
            when write_word_retrieve =>
                backend2slv_buf.address <= write_address_to_send;
                backend2slv_buf.readReady <= '0';
                backend2slv_buf.writeReady <= '0';
                backend2slv_buf.burst <= '1' when current_word_index > 0 else '0';
                read_word_retrieved_buf <= false;
                line_complete <= false;
                bus_fault <= false;
                next_state <= write_send;
            when write_send =>
                backend2slv_buf.address <= write_address_to_send;
                backend2slv_buf.readReady <= '0';
                backend2slv_buf.writeReady <= '1';
                backend2slv_buf.burst <= '1' when buffered_write_index /= word_index_max else '0';
                read_word_retrieved_buf <= false;
                line_complete <= false;
                bus_fault <= false;
                if slv2backend.fault = '1' then
                    next_state <= transaction_fault;
                elsif slv2backend.valid then
                    if buffered_write_index = word_index_max then
                        next_state <= transaction_completing;
                    else
                        next_state <= write_word_retrieve;
                    end if;
                end if;
            when read_word_store =>
                backend2slv_buf.address <= actual_read_address;
                backend2slv_buf.readReady <= '0';
                backend2slv_buf.writeReady <= '0';
                backend2slv_buf.burst <= '1' when current_word_index /= word_index_max else '0';
                read_word_retrieved_buf <= true;
                line_complete <= false;
                bus_fault <= false;
                if current_word_index = word_index_max then
                    next_state <= transaction_completing;
                else
                    next_state <= read_send;
                end if;
            when read_send =>
                backend2slv_buf.address <= actual_read_address;
                backend2slv_buf.readReady <= '1';
                backend2slv_buf.writeReady <= '0';
                backend2slv_buf.burst <= '1' when current_word_index /= word_index_max else '0';
                read_word_retrieved_buf <= false;
                line_complete <= false;
                bus_fault <= false;
                if slv2backend.fault = '1' then
                    next_state <= transaction_fault;
                elsif slv2backend.valid then
                    next_state <= read_word_store;
                end if;
            when transaction_completing =>
                backend2slv_buf.address <= (others => '-');
                backend2slv_buf.readReady <= '0';
                backend2slv_buf.writeReady <= '0';
                backend2slv_buf.burst <= '0';
                read_word_retrieved_buf <= false;
                line_complete <= true;
                bus_fault <= false;
                next_state <= idle;
            when transaction_fault =>
                backend2slv_buf.address <= (others => '-');
                backend2slv_buf.readReady <= '0';
                backend2slv_buf.writeReady <= '0';
                backend2slv_buf.burst <= '0';
                read_word_retrieved_buf <= false;
                line_complete <= false;
                bus_fault <= true;
                next_state <= idle;
        end case;
    end process;
end architecture;
