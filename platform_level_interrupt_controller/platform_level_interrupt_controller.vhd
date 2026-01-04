library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.bus_pkg;

entity platform_level_interrupt_controller is
    generic (
        context_count : natural range 1 to 15871;
        interrupt_source_count : natural range 2 to 1023;
        interrupt_priority_level_count_log2b : natural range 1 to 32
    );
    port (
        clk : in std_logic;
        reset : in boolean;

        mst2slv : in bus_pkg.bus_mst2slv_type;
        slv2mst : out bus_pkg.bus_slv2mst_type;

        interrupt_signal_from_source : in boolean_vector(interrupt_source_count - 1 downto 1);
        interrupt_notification_to_context : out boolean_vector(context_count - 1 downto 0)
    );
end entity;

architecture behavioral of platform_level_interrupt_controller is
    signal slv2mst_buf : bus_pkg.bus_slv2mst_type := bus_pkg.BUS_SLV2MST_IDLE;

    constant priority_mask : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(2**interrupt_priority_level_count_log2b - 1, 32));

    constant interrupt_word_count : natural := (interrupt_signal_from_source'high + 31)/32;
    constant interrupt_word_range_high : natural := interrupt_word_count*32 - 1;
    constant interrupt_word_range_low : natural := 0;
    subtype interrupt_word_range is natural range interrupt_word_range_high downto interrupt_word_range_low;

    type interrupt_priority_level_array_type is array (1 to interrupt_source_count - 1) of unsigned(31 downto 0);
    signal interrupt_priority_level_array : interrupt_priority_level_array_type := (others => (others => '0'));

    signal interrupt_pending_vector : boolean_vector(interrupt_word_range);

    type interrupt_enable_for_context_type is array(0 to context_count - 1) of boolean_vector(interrupt_word_range);
    signal interrupt_enable_for_context : interrupt_enable_for_context_type := (others => (others => false));

    type interrupt_priority_treshold_for_context_vector_type is array(0 to context_count - 1) of unsigned(31 downto 0);
    signal interrupt_priority_treshold_for_context_vector : interrupt_priority_treshold_for_context_vector_type := (others => (others => '0'));

    type interrupt_pending_for_context_vector_type is array(0 to context_count - 1) of natural;
    signal interrupt_pending_for_context_vector : interrupt_pending_for_context_vector_type := (others => 0);

    signal is_interrupt_claimed_vector : boolean_vector(interrupt_word_range) := (others => false);

    signal pending_claimed_merged_vector : boolean_vector(interrupt_word_range) := (others => false);

    pure function bool_vec_to_std_logic_vec(
        input : boolean_vector
    ) return std_logic_vector is
        variable ret : std_logic_vector(input'range);
    begin
        for i in input'low to input'high loop
            ret(i) := '1' when input(i) else '0';
        end loop;
        return ret;
    end function;

    pure function std_logic_vec_to_bool_vec(
        input : std_logic_vector
    ) return boolean_vector is
        variable ret : boolean_vector(input'range);
    begin
        for i in input'low to input'high loop
            ret(i) := true when input(i) = '1' else false;
        end loop;
        return ret;
    end function;

begin
    slv2mst <= slv2mst_buf;
    pending_claimed_merged_vector <= interrupt_pending_vector and not is_interrupt_claimed_vector;
    process (clk)
        variable slv2mst_tmp : bus_pkg.bus_slv2mst_type := bus_pkg.BUS_SLV2MST_IDLE;
        variable base_address : natural;
        variable is_write_op : boolean;
        variable is_read_op : boolean;
        variable address : natural;

        variable context_id : natural;
        variable interrupt_id : natural;
        variable register_index : natural;

        variable priority_to_beat : unsigned(31 downto 0);
        variable interrupt_priority : unsigned(31 downto 0);
    begin
        if rising_edge(clk) then
            if reset then
                slv2mst_buf <= bus_pkg.BUS_SLV2MST_IDLE;
                slv2mst_tmp := bus_pkg.BUS_SLV2MST_IDLE;
                interrupt_priority_level_array <= (others => (others => '0'));
                interrupt_enable_for_context <= (others => (others => false));
                interrupt_priority_treshold_for_context_vector <= (others => (others => '0'));
                is_interrupt_claimed_vector <= (others => false);
            elsif bus_pkg.any_transaction(mst2slv, slv2mst_buf) then
                slv2mst_buf <= bus_pkg.BUS_SLV2MST_IDLE;
                slv2mst_tmp := bus_pkg.BUS_SLV2MST_IDLE;
            elsif slv2mst_tmp.valid or slv2mst_tmp.fault = '1' then
                slv2mst_buf <= slv2mst_tmp;
            elsif bus_pkg.bus_requesting(mst2slv) then
                slv2mst_tmp.readData := (others => '-');
                slv2mst_tmp.valid := true;
                base_address := to_integer(unsigned(mst2slv.address));
                is_write_op := mst2slv.writeReady = '1';
                is_read_op := mst2slv.readReady = '1';
                assert(not (is_write_op and is_read_op));
                if base_address mod 4 /= 0 then
                    slv2mst_tmp.fault := '1';
                    slv2mst_tmp.faultData := bus_pkg.bus_fault_unaligned_access;
                elsif and mst2slv.byteMask /= '1' then
                    slv2mst_tmp.fault := '1';
                    slv2mst_tmp.faultData := bus_pkg.bus_fault_illegal_byte_mask;
                else

                    if base_address >= 16#000000# and base_address < 16#001000# then
                        interrupt_id := base_address/4;
                        if interrupt_id > 0 and interrupt_id < interrupt_source_count then
                            slv2mst_tmp.readData := std_logic_vector(interrupt_priority_level_array(interrupt_id));
                            if is_write_op then
                                interrupt_priority_level_array(interrupt_id) <= unsigned(mst2slv.writeData and priority_mask);
                            end if;
                        end if;
                    end if;

                    if base_address >= 16#001000# and base_address < 16#001080# then
                        address := base_address - 16#001000#;
                        register_index := address / 4;
                        if register_index < interrupt_word_count then
                            slv2mst_tmp.readData := bool_vec_to_std_logic_vec(pending_claimed_merged_vector(register_index * 32 + 31 downto register_index*32));
                        end if;
                    end if;

                    if base_address >= 16#002000# and base_address < 16#1F2000# then
                        address := base_address - 16#002000#;
                        context_id := address / 16#80#;
                        register_index := (address mod 16#80#) / 4;
                        if context_id < context_count and register_index < interrupt_word_count then
                            interrupt_id := (address mod 16#80#) * 8;
                            slv2mst_tmp.readData := bool_vec_to_std_logic_vec(interrupt_enable_for_context(context_id)(register_index*32 + 31 downto register_index*32));
                            if is_write_op then
                                interrupt_enable_for_context(context_id)(register_index*32 + 31 downto register_index*32) <=
                                    std_logic_vec_to_bool_vec(mst2slv.writeData);
                            end if;
                        end if;
                    end if;

                    if base_address >= 16#200000# and base_address <= 16#3FFF000# then
                        address := base_address - 16#200000#;
                        context_id := address / 16#1000#;
                        if context_id < context_count and address mod 16#1000# = 0 then
                            slv2mst_tmp.readData := std_logic_vector(interrupt_priority_treshold_for_context_vector(context_id));
                            if is_write_op then
                                interrupt_priority_treshold_for_context_vector(context_id) <= unsigned(mst2slv.writeData and priority_mask);
                            end if;
                        end if;

                        if context_id < context_count and address mod 16#1000# = 4 then
                            interrupt_id := interrupt_pending_for_context_vector(context_id);
                            slv2mst_tmp.readData := std_logic_vector(to_unsigned(interrupt_id, slv2mst_tmp.readData'length));
                            if is_read_op and interrupt_id /= 0 then
                                is_interrupt_claimed_vector(interrupt_id) <= true;
                            end if;

                            interrupt_id := to_integer(unsigned(mst2slv.writeData));
                            if is_write_op and interrupt_id > 0 and interrupt_id < interrupt_source_count and interrupt_enable_for_context(context_id)(interrupt_id) then
                                interrupt_pending_vector(interrupt_id) <= false;
                                is_interrupt_claimed_vector(interrupt_id) <= false;
                            end if;
                        end if;
                    end if;
                end if;
            end if;

            for i in interrupt_signal_from_source'low to interrupt_signal_from_source'high loop
                if interrupt_signal_from_source(i) then
                    interrupt_pending_vector(i) <= true;
                end if;
            end loop;

            for context_index in 0 to context_count - 1 loop
                priority_to_beat := interrupt_priority_treshold_for_context_vector(context_index);
                interrupt_pending_for_context_vector(context_index) <= 0;
                for interrupt_index in 1 to interrupt_source_count - 1 loop
                    if not interrupt_pending_vector(interrupt_index) then
                        next;
                    end if;
                    if not interrupt_enable_for_context(context_index)(interrupt_index) then
                        next;
                    end if;
                    if is_interrupt_claimed_vector(interrupt_index) then
                        next;
                    end if;
                    interrupt_priority := interrupt_priority_level_array(interrupt_index);
                    if interrupt_priority > priority_to_beat then
                        interrupt_pending_for_context_vector(context_index) <= interrupt_index;
                        priority_to_beat := interrupt_priority;
                    end if;
                end loop;
            end loop;

            for context_index in 0 to context_count - 1 loop
                if interrupt_pending_for_context_vector(context_index) /= 0 then
                    interrupt_notification_to_context(context_index) <= true;
                else
                    interrupt_notification_to_context(context_index) <= false;
                end if;
            end loop;

            for i in interrupt_word_range loop
                if i < interrupt_signal_from_source'low or i > interrupt_signal_from_source'high then
                    interrupt_pending_vector(i) <= false;
                    is_interrupt_claimed_vector(i) <= false;
                    for context_index in 0 to context_count - 1 loop
                        interrupt_enable_for_context(context_index)(i) <= false;
                    end loop;
                end if;
            end loop;
        end if;
    end process;
end architecture;
