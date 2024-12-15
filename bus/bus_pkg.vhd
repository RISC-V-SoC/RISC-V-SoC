library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package bus_pkg is
    -- General information on the bus:
    -- We follow AXI in the Ready/Valid handshake
    -- The master initiates all communication. When readReady or writeReady become high (they must never be high at the same time) address and possibly writeData must be valid.
    -- Transaction occurs if {read|write}Ready and either the related valid or fault are high at the same time during a rising_edge of the clock. This immidiately finishes the transaction.
    -- A fault sets a faultcode on the faultData.
    -- It is allowed, but not required, to have fault and {read|write}Valid high at the same time. If multiple are high, fault takes precedence.
    -- A read transaction is defined as a moment where rising_edge(clk) AND readReady = '1' AND valid
    -- A write transaction is defined as a moment where rising_edge(clk) AND writeReady = '1' AND valid
    -- A fault transaction is defined as a moment where rising_edge(clk) AND fault = '1'
    --
    -- Note that this implies that a fast master/slave combo are allowed to, for example, keep writeReady and valid high all the time and transact data every rising edge of the clock.
    -- If this is what you want, you should probably still use the burst flag. This works as the INCR mode of AXI and has to be respected by all parties in between the master and slave.
    -- So if some arbiter controls the access of multiple masters to a bus, then without the burst flag the arbiter is allowed to give bus access to another party as soon as the transaction completes.
    -- If the burst flag is high, then the arbiter must keep the selected master on the bus until burst is low.
    --
    -- When burst is active, multiple reads/writes can happen in quick succession.
    -- The address must be increased (not decreased!) with exactly bus_bytes_per_word between two bursts, the slave does not have to check this.
    -- The operation (read or write) must remain the same within a burst, the slave does not have to check this.
    -- The byte mask must remain the same within a burst, the slave does not have to check this.
    -- The master must keep burst high until the last transaction. When the Ready of the last transaction rises, the burst has to fall.
    --
    -- The bus is byte-adressable. The data width of the bus is called a word and is always a multiple of the amount of bytes.

    -- These are the relevant sizes of the bus. They are defined like this because if they are not a power of 2,
    -- some things, like remapping, will become impossible.
    constant bus_byte_size_log2b : natural := 3;
    constant bus_address_width_log2b : natural := 5;
    -- Make sure that data_width >= byte_size.
    constant bus_data_width_log2b : natural := 5;

    constant bus_byte_size    : natural := 2**bus_byte_size_log2b;
    constant bus_fault_size   : natural := 4;

    subtype bus_address_type     is std_logic_vector(2**bus_address_width_log2b - 1 downto  0); -- Any bus address.
    subtype bus_data_type        is std_logic_vector(2**bus_data_width_log2b - 1 downto  0); -- Any data word.
    subtype bus_byte_type        is std_logic_vector(bus_byte_size - 1 downto 0);   -- A byte, lowest adressable unit
    subtype bus_fault_type       is std_logic_vector(bus_fault_size - 1 downto 0); -- any bus fault word

    constant bus_bytes_per_word : positive := bus_data_type'length / bus_byte_size;
    constant bus_bytes_per_word_log2b : natural := bus_data_width_log2b - bus_byte_size_log2b;

    subtype bus_aligned_address_type is std_logic_vector(2**bus_address_width_log2b - 1 downto bus_bytes_per_word_log2b); -- Any bus address that is aligned to the bus.

    type bus_data_array is array (natural range <>) of bus_data_type;
    type bus_byte_array is array (natural range <>) of bus_byte_type;
    type bus_aligned_address_array is array (natural range <>) of bus_aligned_address_type;

    subtype bus_byte_mask_type is std_logic_vector(bus_bytes_per_word - 1 downto 0);

    -- Some predefined faults
    constant bus_fault_no_fault : bus_fault_type :=                     std_logic_vector(to_unsigned(0, bus_fault_type'length));
    constant bus_fault_unaligned_access : bus_fault_type :=             std_logic_vector(to_unsigned(1, bus_fault_type'length));
    constant bus_fault_address_out_of_range : bus_fault_type :=         std_logic_vector(to_unsigned(2, bus_fault_type'length));
    constant bus_fault_illegal_byte_mask : bus_fault_type :=           std_logic_vector(to_unsigned(3, bus_fault_type'length));
    constant bus_fault_illegal_address_for_burst : bus_fault_type :=    std_logic_vector(to_unsigned(4, bus_fault_type'length));

    -- The remapping logic.
    -- Any range of input can be placed at any range of output. Moreover, parts of the output can be set to 0 or 1.
    -- As an example, take a device which has registers on address 0 to 3, but in reality lives on address 1 to 4.
    -- A correct remapping would now be: bus_map_constant(1, '0') & bus_map_range(bus_address_type'high - 1, 0)
    type bitMapping_array is array (natural range <>) of integer;
    -- Using this type makes sure that the bitmapping aray is always exactly long enough.
    subtype addrMapping_type is bitMapping_array(bus_address_type'range);

    type bus_mst2slv_type is record
        address         : bus_address_type;
        writeData       : bus_data_type;
        byteMask       : bus_byte_mask_type;
        readReady       : std_logic;
        writeReady      : std_logic;
        burst           : std_logic;
    end record;

    type bus_mst2slv_array is array (natural range <>) of bus_mst2slv_type;

    type bus_slv2mst_type is record
        readData        : bus_data_type;
        valid           : boolean;
        fault           : std_logic;
        faultData       : bus_fault_type;
    end record;

    type bus_slv2mst_array is array (natural range <>) of bus_slv2mst_type;

    type addr_range_type is record
        low       : bus_address_type;
        high      : bus_address_type;
    end record;

    type addr_range_and_mapping_type is record
        addr_range  : addr_range_type;
        mapping     : addrMapping_type;
    end record;

    type addr_range_and_mapping_array is array (natural range <>) of addr_range_and_mapping_type;

    constant BUS_MST2SLV_IDLE : bus_mst2slv_type := (
        address => (others => 'X'),
        writeData => (others => 'X'),
        byteMask => (others => 'X'),
        readReady => '0',
        writeReady => '0',
        burst => '0'
    );

    constant BUS_SLV2MST_IDLE : bus_slv2mst_type := (
        readData => (others => 'X'),
        valid => false,
        fault => '0',
        faultData => (others => 'X')
    );

    -- Returns true when the specified master is requesting something.
    pure function bus_requesting(
        b     : bus_mst2slv_type
    ) return boolean;

    pure function read_transaction(
        mst  : bus_mst2slv_type;
        slv  : bus_slv2mst_type
    ) return boolean;

    pure function write_transaction(
        mst  : bus_mst2slv_type;
        slv  : bus_slv2mst_type
    ) return boolean;

    pure function fault_transaction(
        mst  : bus_mst2slv_type;
        slv  : bus_slv2mst_type
    ) return boolean;

    pure function any_transaction(
        mst : bus_mst2slv_type;
        slv : bus_slv2mst_type
    ) return boolean;

    pure function no_transaction (
        mst : bus_mst2slv_type;
        slv : bus_slv2mst_type
    ) return boolean;

    pure function bus_mst2slv_read (
        address : bus_address_type;
        byte_mask : bus_byte_mask_type := (others => '1');
        burst   : std_logic := '0'
    ) return bus_mst2slv_type;

    pure function bus_mst2slv_write (
        address : bus_address_type;
        write_data : bus_data_type;
        byte_mask : bus_byte_mask_type := (others => '1');
        burst   : std_logic := '0'
    ) return bus_mst2slv_type;

    function bus_addr_in_range(
        addr        : bus_address_type;
        addr_range  : addr_range_type
    ) return boolean;

    pure function bus_addr_is_aligned_to_bus(
        addr : bus_address_type
    ) return boolean;

    -- Mapping functions
    function bus_map_range(
        high      : natural;
        low       : natural
    ) return bitMapping_array;

    function bus_map_constant(
        count     : natural;
        value     : std_logic
    ) return bitMapping_array;

    function address_range_and_map (
        low     : bus_address_type := (others => '0');
        high    : bus_address_type := (others => '1');
        mapping : addrMapping_type := bus_map_range(bus_address_type'high, 0)
    ) return addr_range_and_mapping_type;

    function bus_apply_addr_map(
        addr      : bus_address_type;
        addrMap   : addrMapping_type
    ) return bus_address_type;

    pure function bus_mst_active (
        mst : bus_mst2slv_type
    ) return boolean;

end bus_pkg;

package body bus_pkg is

    pure function bus_requesting(
        b   : bus_mst2slv_type
    ) return boolean is
    begin
        return b.readReady = '1' or b.writeReady = '1';
    end bus_requesting;

    pure function read_transaction(
        mst  : bus_mst2slv_type;
        slv  : bus_slv2mst_type
    ) return boolean is
    begin
        return mst.readReady = '1' and slv.valid and slv.fault /= '1';
    end read_transaction;

    pure function write_transaction(
        mst  : bus_mst2slv_type;
        slv  : bus_slv2mst_type
    ) return boolean is
    begin
        return mst.writeReady = '1' and slv.valid and slv.fault /= '1';
    end write_transaction;

    pure function fault_transaction(
        mst  : bus_mst2slv_type;
        slv  : bus_slv2mst_type
    ) return boolean is
    begin
        return (mst.readReady = '1' or mst.writeReady = '1') and slv.fault = '1';
    end fault_transaction;

    pure function any_transaction(
        mst : bus_mst2slv_type;
        slv : bus_slv2mst_type
    ) return boolean is
    begin
        return write_transaction(mst, slv) or read_transaction(mst, slv) or fault_transaction(mst, slv);
    end any_transaction;

    pure function no_transaction (
        mst : bus_mst2slv_type;
        slv : bus_slv2mst_type
    ) return boolean is
    begin
        return not any_transaction(mst, slv);
    end no_transaction;

    pure function bus_mst2slv_read (
        address : bus_address_type;
        byte_mask : bus_byte_mask_type := (others => '1');
        burst   : std_logic := '0'
    ) return bus_mst2slv_type is
        variable ret_val : bus_mst2slv_type := BUS_MST2SLV_IDLE;
    begin
        ret_val.address := address;
        ret_val.burst := burst;
        ret_val.readReady := '1';
        ret_val.byteMask := byte_mask;
        return ret_val;
    end bus_mst2slv_read;

    pure function bus_mst2slv_write (
        address : bus_address_type;
        write_data : bus_data_type;
        byte_mask : bus_byte_mask_type := (others => '1');
        burst   : std_logic := '0'
    ) return bus_mst2slv_type is
        variable ret_val : bus_mst2slv_type := BUS_MST2SLV_IDLE;
    begin
        ret_val.address := address;
        ret_val.writeData := write_data;
        ret_val.byteMask := byte_mask;
        ret_val.burst := burst;
        ret_val.writeReady := '1';
        return ret_val;
    end bus_mst2slv_write;

    function bus_addr_in_range (
        addr        : bus_address_type;
        addr_range  : addr_range_type
    ) return boolean is
    begin
        return unsigned(addr) >= unsigned(addr_range.low) and unsigned(addr) <= unsigned(addr_range.high);
    end bus_addr_in_range;

    pure function bus_addr_is_aligned_to_bus (
        addr : bus_address_type
    ) return boolean is
    begin
        for i in 0 to bus_bytes_per_word_log2b - 1 loop
            if addr(i) = '1' then
                return false;
            end if;
        end loop;
        return true;
    end function;

    function bus_map_range(
        high      : natural;
        low       : natural
    ) return bitMapping_array is
        variable res : bitMapping_array(high-low downto 0);
    begin
        for i in res'range loop
            res(i) := i + low;
        end loop;
        return res;
    end bus_map_range;

    function bus_map_constant(
        count     : natural;
        value     : std_logic
    ) return bitMapping_array is
        variable res : bitMapping_array(count-1 downto 0);
    begin
        if value = '1' then
            for i in 0 to count - 1 loop
                res(i) := -2; -- Code for '1'.
            end loop;
        else
            for i in 0 to count - 1 loop
                res(i) := -1; -- Code for '0'.
            end loop;
        end if;
        return res;
    end bus_map_constant;

    function address_range_and_map (
        low     : bus_address_type := (others => '0');
        high    : bus_address_type := (others => '1');
        mapping : addrMapping_type := bus_map_range(bus_address_type'high, 0)
    ) return addr_range_and_mapping_type is
        variable retval   : addr_range_and_mapping_type;
    begin
        retval.addr_range := (
            low   => low,
            high  => high
        );
        retval.mapping := mapping;
        return retval;
    end address_range_and_map;

    function bus_apply_addr_map(
        addr      : bus_address_type;
        addrMap   : addrMapping_type
    ) return bus_address_type is
        variable res : bus_address_type;
    begin
        for i in res'range loop
            if addrMap(i) = -2 then -- Code for '1'.
                res(i) := '1';
            elsif addrMap(i) = -1 then -- Code for '0'.
                res(i) := '0';
            else
                res(i) := addr(addrMap(i));
            end if;
        end loop;
        return res;
    end bus_apply_addr_map;

    pure function bus_mst_active (
        mst : bus_mst2slv_type
    ) return boolean is
    begin
        return bus_requesting(mst) or mst.burst = '1';
    end function;
end bus_pkg;
