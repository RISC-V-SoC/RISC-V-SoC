library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library src;
use src.bus_pkg.all;

package bus_tb_pkg is

    pure function bus_tb_mst2slv(
        address : natural := 0;
        writeData    : natural := 0;
        byteMask : natural range 0 to 2**bus_byte_mask_type'length - 1 := 0;
        readReady : std_logic := '0';
        writeReady : std_logic := '0';
        burst : std_logic := '0'
    ) return bus_mst2slv_type;

end bus_tb_pkg;

package body bus_tb_pkg is

    pure function bus_tb_mst2slv(
        address : natural := 0;
        writeData    : natural := 0;
        byteMask : natural range 0 to 2**bus_byte_mask_type'length - 1 := 0;
        readReady : std_logic := '0';
        writeReady : std_logic := '0';
        burst : std_logic := '0'
    ) return bus_mst2slv_type is
        variable retval : bus_mst2slv_type;
    begin
        retval.address := std_logic_vector(to_unsigned(address, bus_address_type'length));
        retval.writeData := std_logic_vector(to_unsigned(writeData, bus_data_type'length));
        retval.byteMask := std_logic_vector(to_unsigned(byteMask, bus_byte_mask_type'length));
        retval.readReady := readReady;
        retval.writeReady := writeReady;
        retval.burst := burst;
        return retval;
    end bus_tb_mst2slv;
end bus_tb_pkg;
