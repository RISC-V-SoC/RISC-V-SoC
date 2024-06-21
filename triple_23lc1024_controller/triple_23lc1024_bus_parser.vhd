library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg;
use work.triple_23lc1024_pkg.all;

entity triple_23lc1024_bus_parser is
    port (
        clk : in std_logic;
        rst : in boolean;

        mst2slv : in bus_pkg.bus_mst2slv_type;
        transaction_valid : in boolean;
        any_active : in boolean;

        request_length : out positive range 1 to bus_pkg.bus_bytes_per_word;
        cs_request : out cs_request_type;
        fault_data : out bus_pkg.bus_fault_type;
        write_data : out bus_pkg.bus_data_type;
        address : out bus_pkg.bus_address_type;

        has_fault : out boolean;
        read_request : out boolean;
        write_request : out boolean;
        virtual_write_burst : out boolean
    );
end entity;

architecture behavioral of triple_23lc1024_bus_parser is
    subtype request_length_type is natural range 0 to bus_pkg.bus_bytes_per_word;

    pure function count_leading_zeros (
        byte_mask : bus_pkg.bus_byte_mask_type) return natural is
            variable ret_val : natural := 0;
    begin
       for i in 0 to bus_pkg.bus_byte_mask_type'high loop
           if byte_mask(i) = '0' then
               ret_val := ret_val + 1;
            else
                exit;
           end if;
       end loop;
       return ret_val;
    end function;

    pure function count_trailing_zeros (
        byte_mask : bus_pkg.bus_byte_mask_type) return natural is
            variable ret_val : natural := 0;
    begin
       for i in 0 to bus_pkg.bus_byte_mask_type'high loop
           if byte_mask(bus_pkg.bus_byte_mask_type'high - i) = '0' then
               ret_val := ret_val + 1;
            else
                exit;
           end if;
       end loop;
       return ret_val;
    end function;

    pure function count_total_zeros (
        byte_mask : bus_pkg.bus_byte_mask_type) return natural is
            variable ret_val : natural := 0;
    begin
       for i in 0 to bus_pkg.bus_byte_mask_type'high loop
           if byte_mask(i) = '0' then
               ret_val := ret_val + 1;
           end if;
       end loop;
       return ret_val;
    end function;

    pure function is_boundry_crossing(
        first_address : unsigned(bus_pkg.bus_address_type'range);
        second_address : unsigned(bus_pkg.bus_address_type'range)) return boolean is
    begin
        return first_address(16 downto 0) > second_address(16 downto 0);
    end function;

    pure function is_boundry_crossing(
        first_address : bus_pkg.bus_address_type;
        second_address : bus_pkg.bus_address_type) return boolean is
    begin
        return is_boundry_crossing(unsigned(first_address), unsigned(second_address));
    end function;

    procedure check_mask_alignment (
        signal lsb : in std_logic_vector(1 downto 0);
        signal byte_mask : in bus_pkg.bus_byte_mask_type;
        variable has_fault_buf : out boolean;
        variable fault_data_buf : out bus_pkg.bus_fault_type) is
    begin
        has_fault_buf := false;
        fault_data_buf := (others => 'X');
        if byte_mask = "1111" then
            if lsb /= "00" then
                has_fault_buf := true;
                fault_data_buf := bus_pkg.bus_fault_unaligned_access;
            end if;
        elsif byte_mask = "0011" then
            if lsb(0) /= '0' then
                has_fault_buf := true;
                fault_data_buf := bus_pkg.bus_fault_unaligned_access;
            end if;
        elsif byte_mask = "0001" then
            has_fault_buf := false;
        elsif count_leading_zeros(byte_mask) + count_trailing_zeros(byte_mask) /= count_total_zeros(byte_mask) then
            has_fault_buf := true;
            fault_data_buf := bus_pkg.bus_fault_illegal_byte_mask;
        elsif lsb /= "00" or byte_mask = "0000" then
            has_fault_buf := true;
            fault_data_buf := bus_pkg.bus_fault_illegal_byte_mask;
        end if;
    end procedure;

    procedure detect_fault (
        signal mst2slv_buf : in bus_pkg.bus_mst2slv_type;
        variable has_fault_buf : out boolean;
        variable fault_data_buf : out bus_pkg.bus_fault_type) is
        constant max_address : unsigned(31 downto 0) := X"0005FFFF";
        variable current_address : unsigned(31 downto 0) := unsigned(mst2slv_buf.address);
        variable next_address_on_burst : unsigned(31 downto 0) := unsigned(mst2slv_buf.address) + to_unsigned(bus_pkg.bus_bytes_per_word, 31);
    begin
        check_mask_alignment(mst2slv_buf.address(1 downto 0), mst2slv_buf.byteMask, has_fault_buf, fault_data_buf);
        if not has_fault_buf then
            if current_address > max_address then
                has_fault_buf := true;
                fault_data_buf := bus_pkg.bus_fault_address_out_of_range;
            elsif mst2slv_buf.burst = '1' and is_boundry_crossing(current_address, next_address_on_burst) then
                has_fault_buf := true;
                fault_data_buf := bus_pkg.bus_fault_illegal_address_for_burst;
            else
                has_fault_buf := false;
                fault_data_buf := (others => 'X');
            end if;
        end if;
    end procedure;

    pure function determine_read_request_length (
        byte_mask : bus_pkg.bus_byte_mask_type) return natural is
            variable ret_val : natural := 0;
    begin
        if byte_mask = "0001" then
            ret_val := 1;
        elsif byte_mask = "0011" then
            ret_val := 2;
        else
            ret_val := 4;
        end if;
        return ret_val;
    end function;

    pure function determine_write_request_length (
        byte_mask : bus_pkg.bus_byte_mask_type) return natural is
            variable ret_val : natural := 0;
    begin
       for i in 0 to bus_pkg.bus_byte_mask_type'high loop
           if byte_mask(i) = '1' then
               ret_val := ret_val + 1;
           end if;
       end loop;
       return ret_val;
    end function;

    pure function is_virtual_write_burst (
        prev_address : bus_pkg.bus_address_type;
        cur_address : bus_pkg.bus_address_type;
        prev_length : request_length_type;
        cur_length : request_length_type) return boolean is
    begin
        return (unsigned(cur_address) = unsigned(prev_address) + prev_length) and (prev_length = cur_length) and not is_boundry_crossing(prev_address, cur_address);
    end function;
begin
    process(clk)
        variable has_fault_buf : boolean := false;
        variable fault_data_buf : bus_pkg.bus_fault_type := bus_pkg.bus_fault_no_fault;
        variable request_length_buf : request_length_type;
        variable wait_out_active : boolean := false;
        variable effective_address : bus_pkg.bus_address_type;

        variable previous_operation_was_write : boolean := false;
        variable previous_effective_address : bus_pkg.bus_address_type;
        variable previous_request_length : request_length_type;
    begin
        if rising_edge(clk) then
            has_fault <= false;
            if rst then
                read_request <= false;
                write_request <= false;
                virtual_write_burst <= false;
                has_fault_buf := false;
                previous_operation_was_write := false;
            elsif wait_out_active then
                wait_out_active := any_active;
            elsif has_fault_buf then
                has_fault <= true;
                has_fault_buf := false;
                fault_data <= fault_data_buf;
                wait_out_active := any_active;
                read_request <= false;
                write_request <= false;
                virtual_write_burst <= false;
            elsif bus_pkg.bus_requesting(mst2slv) and transaction_valid then
                previous_operation_was_write := true when mst2slv.writeReady = '1' else false;
                previous_effective_address := effective_address;
                previous_request_length := request_length_buf;
                read_request <= false;
                write_request <= false;
                virtual_write_burst <= false;
            elsif bus_pkg.bus_requesting(mst2slv) then
                detect_fault(mst2slv, has_fault_buf, fault_data_buf);
                if has_fault_buf then
                    read_request <= false;
                    write_request <= false;
                else
                    read_request <= true when mst2slv.readReady = '1' else false;
                    write_request <= true when mst2slv.writeReady = '1' else false;
                end if;

                cs_request <= encode_cs_request_type(mst2slv.address);
                if mst2slv.readReady = '1' then
                    request_length_buf := determine_read_request_length(mst2slv.byteMask);
                else
                    request_length_buf := determine_write_request_length(mst2slv.byteMask);
                end if;

                write_data <= std_logic_vector(shift_right(unsigned(mst2slv.writeData), count_leading_zeros(mst2slv.byteMask)*bus_pkg.bus_byte_size));
                effective_address := std_logic_vector(unsigned(mst2slv.address) + count_leading_zeros(mst2slv.byteMask));

                if request_length_buf = 0 then
                    request_length <= 1;
                else
                    request_length <= request_length_buf;
                end if;

                if mst2slv.writeReady = '1' and previous_operation_was_write then
                    virtual_write_burst <= is_virtual_write_burst(previous_effective_address, effective_address, previous_request_length, request_length_buf);
                else
                    virtual_write_burst <= false;
                end if;
            end if;
        end if;
        address <= effective_address;
    end process;

end architecture;
