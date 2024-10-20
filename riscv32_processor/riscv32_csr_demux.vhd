library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_csr_demux is
    generic (
        mapping_array : riscv32_csr_mapping_array
    );
    port (
        csr_in : in riscv32_to_csr_type;
        csr_out : out riscv32_from_csr_type;

        demux2slv : out riscv32_csr_mst2slv_array(mapping_array'range);
        slv2demux : in riscv32_csr_slv2mst_array(mapping_array'range)
    );
end entity;

architecture behaviourial of riscv32_csr_demux is

    alias access_mode : std_logic_vector(1 downto 0) is csr_in.address(11 downto 10);
    signal decoded_address : natural range 0 to 4095;
    signal decoded_subaddress : natural range 0 to 255;
    signal error_buf : boolean;
    signal read_data_buf : riscv32_data_type;
    signal out_of_range_error : boolean;
    signal error_from_slave : boolean;
    signal readonly_error : boolean;
    signal processed_write_data : riscv32_data_type;

    pure function address_in_range(
        address : natural range 0 to 4095;
        mapping : riscv32_csr_mapping_type
    ) return boolean is
    begin
        return address >= mapping.address_low and address < mapping.address_low + mapping.mapping_size;
    end function;
begin
    readonly_error <= csr_in.do_write and access_mode = "11";
    decoded_address <= to_integer(unsigned(csr_in.address));
    decoded_subaddress <= decoded_address mod 256;
    csr_out.error <= error_buf;
    csr_out.data <= read_data_buf;

    process_write_data : process(csr_in, read_data_buf)
    begin
        if csr_in.command = csr_rs then
            processed_write_data <= csr_in.data_in or read_data_buf;
        elsif csr_in.command = csr_rc then
            processed_write_data <= not csr_in.data_in and read_data_buf;
        else
            processed_write_data <= csr_in.data_in;
        end if;
    end process;

    error_output_handling : process(csr_in, out_of_range_error, error_from_slave, readonly_error)
    begin
        if not (csr_in.do_read or csr_in.do_write) then
            error_buf <= false;
        elsif readonly_error then
            error_buf <= true;
        elsif out_of_range_error then
            error_buf <= true;
        else
            error_buf <= error_from_slave;
        end if;
    end process;

    out_of_range_error_handling : process(decoded_address)
    begin
        out_of_range_error <= true;
        for i in mapping_array'range loop
            if address_in_range(decoded_address, mapping_array(i)) then
                out_of_range_error <= false;
                exit;
            end if;
        end loop;
    end process;

    forward_handling : process(csr_in, decoded_address, decoded_subaddress, error_buf, processed_write_data)
    begin
        for i in mapping_array'range loop
            demux2slv(i).address <= decoded_subaddress;
            demux2slv(i).write_data <= (others => '-');
            if address_in_range(decoded_address, mapping_array(i)) and not error_buf then
                demux2slv(i).do_read <= csr_in.do_read;
                demux2slv(i).do_write <= csr_in.do_write;
                demux2slv(i).write_data <= processed_write_data;
            else
                demux2slv(i).do_read <= false;
                demux2slv(i).do_write <= false;
            end if;
        end loop;
    end process;

    data_from_slave_handling : process(csr_in, decoded_address, slv2demux)
    begin
        read_data_buf <= (others => '-');
        error_from_slave <= false;
        for i in mapping_array'range loop
            if address_in_range(decoded_address, mapping_array(i)) then
                read_data_buf <= slv2demux(i).read_data;
                error_from_slave <= slv2demux(i).has_error;
                exit;
            end if;
        end loop;
    end process;

end architecture;
