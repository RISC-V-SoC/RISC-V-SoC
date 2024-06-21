library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;
use work.riscv32_pkg.all;

entity riscv32_bus_slave is
    port (
        clk : in std_logic;
        rst : in boolean;

        mst2slv : in bus_mst2slv_type;
        slv2mst : out bus_slv2mst_type;

        address_to_ci : out natural range 0 to 31;
        write_to_ci : out boolean;
        data_to_ci : out riscv32_data_type;
        data_from_ci : in riscv32_data_type;

        address_to_regFile : out natural range 0 to 31;
        write_to_regFile : out boolean;
        data_to_regFile : out riscv32_data_type;
        data_from_regFile : in riscv32_data_type
    );
end entity;

architecture behaviourial of riscv32_bus_slave is
    signal address_internal : riscv32_address_type := (others => '0');
    signal data_in_internal : riscv32_data_type;
    signal data_out_internal : riscv32_data_type;
    signal recalculated_address : unsigned(address_internal'high - 2 downto 0);
    signal do_write_internal : boolean;
begin
    recalculated_address <= unsigned(address_internal(address_internal'high downto 2));
    data_to_ci <= data_out_internal;
    data_to_regFile <= data_out_internal;

    demuxer: process(recalculated_address, data_from_ci, data_from_regFile, do_write_internal)
        variable temp_address : unsigned(recalculated_address'range);
    begin
        address_to_ci <= to_integer(recalculated_address(4 downto 0));
        if recalculated_address >= 32 then
            temp_address := recalculated_address - 32;
            address_to_regFile <= to_integer(temp_address(4 downto 0));
            data_in_internal <= data_from_regFile;
            write_to_regFile <= do_write_internal;
            write_to_ci <= false;
        else
            address_to_regFile <= 0;
            data_in_internal <= data_from_ci;
            write_to_ci <= do_write_internal;
            write_to_regFile <= false;
        end if;
    end process;

    process(clk)
        variable slv2mst_buf : bus_slv2mst_type := BUS_SLV2MST_IDLE;
        variable internal_transaction : boolean := false;
        variable has_fault : boolean := false;
        variable fault_data : bus_fault_type;
    begin
        if rising_edge(clk) then
            do_write_internal <= false;
            if rst then
                slv2mst_buf := BUS_SLV2MST_IDLE;
                has_fault := false;
                internal_transaction := false;
                do_write_internal <= false;
            elsif any_transaction(mst2slv, slv2mst_buf) then
                slv2mst_buf := BUS_SLV2MST_IDLE;
            elsif has_fault then
                has_fault := false;
                slv2mst_buf.fault := '1';
                slv2mst_buf.faultData := fault_data;
            elsif internal_transaction then
                internal_transaction := false;
                slv2mst_buf.valid := true;
                slv2mst_buf.readData := data_in_internal;
            elsif bus_requesting(mst2slv) then
                if mst2slv.address(1 downto 0) /= "00" then
                    has_fault := true;
                    fault_data := bus_fault_unaligned_access;
                elsif mst2slv.bytemask /= "1111" then
                    has_fault := true;
                    fault_data := bus_fault_illegal_byte_mask;
                else
                    address_internal <= mst2slv.address;
                    data_out_internal <= mst2slv.writeData;
                    do_write_internal <= mst2slv.writeReady = '1';
                    internal_transaction := true;
                end if;
            end if;
        end if;
        slv2mst <= slv2mst_buf;
    end process;

end behaviourial;
