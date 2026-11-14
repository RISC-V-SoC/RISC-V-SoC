library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package debug_module_pkg is
    -- General rules here are similar to the "bus" (see bus_pkg.vhd).
    -- Important difference is here is that the smallest addressable word is 32 bit instead of 8 bit.
    -- Another important difference is the lack of errors. Writing to a non-existing register is a no-op,
    -- reading from a non-existing register results in 0.
    -- This bus should really only be placed between the debug module interface and the debug module

    constant debug_module_bus_address_width_log2b : natural := 5;
    constant debug_module_bus_data_width_log2b : natural := 5;

    subtype debug_module_bus_address_type is std_ulogic_vector(2**debug_module_bus_address_width_log2b - 1 downto  0);
    subtype debug_module_bus_data_type is std_ulogic_vector(2**debug_module_bus_data_width_log2b - 1 downto  0);

    type debug_module_bus_data_array is array (natural range <>) of debug_module_bus_data_type;

    type debug_module_bus_mst2slv_type is record
        address         : debug_module_bus_address_type;
        writeData       : debug_module_bus_data_type;
        readReady       : boolean;
        writeReady      : boolean;
    end record;

    type debug_module_bus_slv2mst_type is record
        readData        : debug_module_bus_data_type;
        valid           : boolean;
    end record;

    constant DEBUG_MODULE_BUS_MST2SLV_IDLE : debug_module_bus_mst2slv_type := (
        address => (others => 'X'),
        writeData => (others => 'X'),
        readReady => false,
        writeReady => false
    );

    constant DEBUG_MODULE_BUS_SLV2MST_IDLE : debug_module_bus_slv2mst_type := (
        readData => (others => 'X'),
        valid => false
    );

    pure function debug_module_bus_requesting(
        b     : debug_module_bus_mst2slv_type
    ) return boolean;

    pure function debug_module_bus_read_transaction(
        mst  : debug_module_bus_mst2slv_type;
        slv  : debug_module_bus_slv2mst_type
    ) return boolean;

    pure function debug_module_bus_write_transaction(
        mst  : debug_module_bus_mst2slv_type;
        slv  : debug_module_bus_slv2mst_type
    ) return boolean;

    pure function debug_module_bus_any_transaction(
        mst : debug_module_bus_mst2slv_type;
        slv : debug_module_bus_slv2mst_type
    ) return boolean;

    pure function debug_module_bus_no_transaction (
        mst : debug_module_bus_mst2slv_type;
        slv : debug_module_bus_slv2mst_type
    ) return boolean;

    pure function debug_module_bus_mst2slv_read (
        address : debug_module_bus_address_type
    ) return debug_module_bus_mst2slv_type;

    pure function debug_module_bus_mst2slv_write (
        address : debug_module_bus_address_type;
        write_data : debug_module_bus_data_type
    ) return debug_module_bus_mst2slv_type;

end debug_module_pkg;

package body debug_module_pkg is

    pure function debug_module_bus_requesting(
        b     : debug_module_bus_mst2slv_type
    ) return boolean is
    begin
        return b.readReady or b.writeReady;
    end function;

    pure function debug_module_bus_read_transaction(
        mst  : debug_module_bus_mst2slv_type;
        slv  : debug_module_bus_slv2mst_type
    ) return boolean is
    begin
        return mst.readReady and slv.valid;
    end function;

    pure function debug_module_bus_write_transaction(
        mst  : debug_module_bus_mst2slv_type;
        slv  : debug_module_bus_slv2mst_type
    ) return boolean is
    begin
        return mst.writeReady and slv.valid;
    end function;

    pure function debug_module_bus_any_transaction(
        mst : debug_module_bus_mst2slv_type;
        slv : debug_module_bus_slv2mst_type
    ) return boolean is
    begin
        return debug_module_bus_read_transaction(mst, slv) or debug_module_bus_write_transaction(mst, slv);
    end function;

    pure function debug_module_bus_no_transaction (
        mst : debug_module_bus_mst2slv_type;
        slv : debug_module_bus_slv2mst_type
    ) return boolean is
    begin
        return not debug_module_bus_any_transaction(mst, slv);
    end function;

    pure function debug_module_bus_mst2slv_read (
        address : debug_module_bus_address_type
    ) return debug_module_bus_mst2slv_type is
        variable ret_val : debug_module_bus_mst2slv_type := DEBUG_MODULE_BUS_MST2SLV_IDLE;
    begin
        ret_val.address := address;
        ret_val.readReady := true;
        return ret_val;
    end function;

    pure function debug_module_bus_mst2slv_write (
        address : debug_module_bus_address_type;
        write_data : debug_module_bus_data_type
    ) return debug_module_bus_mst2slv_type is
        variable ret_val : debug_module_bus_mst2slv_type := DEBUG_MODULE_BUS_MST2SLV_IDLE;
    begin
        ret_val.address := address;
        ret_val.writeData := write_data;
        ret_val.writeReady := true;
        return ret_val;
    end function;

end debug_module_pkg;
