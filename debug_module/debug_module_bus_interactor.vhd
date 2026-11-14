library ieee;
use ieee.std_logic_1164.all;

library work;
use work.bus_pkg;

entity debug_module_bus_interactor is
    port (
        clk : in std_logic;
        reset : in boolean;

        address : in bus_pkg.bus_address_type;
        write_data : in bus_pkg.bus_data_type;
        read_data : out bus_pkg.bus_data_type;
        byte_mask : in bus_pkg.bus_byte_mask_type;
        fault : out bus_pkg.bus_fault_type;

        do_write : in boolean;
        do_read : in boolean;

        busy : out boolean;
        transaction_complete : out boolean;

        mst2slv : out bus_pkg.bus_mst2slv_type;
        slv2mst : in bus_pkg.bus_slv2mst_type
    );
end entity;

architecture behavioural of debug_module_bus_interactor is
begin

    process(clk)
        variable mst2slv_buf : bus_pkg.bus_mst2slv_type := bus_pkg.BUS_MST2SLV_IDLE;
    begin
        if rising_edge(clk) then
            transaction_complete <= false;
            if reset then
                mst2slv_buf := bus_pkg.BUS_MST2SLV_IDLE;
            elsif bus_pkg.any_transaction(mst2slv_buf, slv2mst) then
                transaction_complete <= true;
                read_data <= slv2mst.readData;
                if bus_pkg.fault_transaction(mst2slv_buf, slv2mst) then
                    fault <= slv2mst.faultData;
                else
                    fault <= bus_pkg.bus_fault_no_fault;
                end if;
                mst2slv_buf := bus_pkg.BUS_MST2SLV_IDLE;
            elsif bus_pkg.bus_requesting(mst2slv_buf) then
                -- pass
            elsif do_read then
                mst2slv_buf := bus_pkg.bus_mst2slv_read(address => address, byte_mask => byte_mask);
            elsif do_write then
                mst2slv_buf := bus_pkg.bus_mst2slv_write(address => address, write_data => write_data, byte_mask => byte_mask);
            end if;
        end if;
        mst2slv <= mst2slv_buf;
        busy <= bus_pkg.bus_requesting(mst2slv_buf);
    end process;
end architecture;
