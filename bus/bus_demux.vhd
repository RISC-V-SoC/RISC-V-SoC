library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;

entity bus_demux is
    generic (
        ADDRESS_MAP         :  addr_range_and_mapping_array
    );
    port (
        mst2demux           : in bus_mst2slv_type;
        demux2mst           : out bus_slv2mst_type;

        demux2slv           : out bus_mst2slv_array(ADDRESS_MAP'range);
        slv2demux           : in bus_slv2mst_array(ADDRESS_MAP'range)
    );
end bus_demux;

architecture behaviourial of bus_demux is
begin

    combinatoral : process(mst2demux, slv2demux)
        variable none_selected  : boolean := true;
    begin
        demux2mst <= BUS_SLV2MST_IDLE;
        for i in 0 to ADDRESS_MAP'high loop
            demux2slv(i) <= BUS_MST2SLV_IDLE;
        end loop;

        none_selected := true;

        if bus_requesting(mst2demux) or mst2demux.burst = '1' then
            for i in 0 to ADDRESS_MAP'high loop
                if bus_addr_in_range(mst2demux.address, ADDRESS_MAP(i).addr_range) then
                    none_selected := false;
                    demux2slv(i) <= mst2demux;
                    demux2slv(i).address <= bus_apply_addr_map(mst2demux.address, ADDRESS_MAP(i).mapping);
                    demux2mst <= slv2demux(i);
                end if;
            end loop;

            if none_selected then
                demux2mst.fault <= '1';
                demux2mst.faultData <= bus_fault_address_out_of_range;
            end if;
        end if;
    end process;
end architecture;
