library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.math_real.all;

library work;
use work.bus_pkg.all;
use work.riscv32_pkg.all;

entity riscv32_mem2bus is
    generic (
        range_to_cache : addr_range_type;
        cache_word_count_log2b : natural
    );
    port (
        clk : in std_logic;
        rst : in boolean;

        forbidBusInteraction : in boolean;
        flushCache : in boolean;

        mst2slv : out bus_mst2slv_type;
        slv2mst : in bus_slv2mst_type;

        hasFault : out boolean;
        faultData : out bus_fault_type;

        address : in riscv32_address_type;
        byteMask : in riscv32_byte_mask_type;
        dataIn : in riscv32_data_type;
        dataOut : out riscv32_data_type;
        doWrite : in boolean;
        doRead : in boolean;

        stall : out boolean
    );
end entity;

architecture behaviourial of riscv32_mem2bus is

    constant cache_range_low : natural := to_integer(unsigned(range_to_cache.low));
    constant cache_range_high : natural := to_integer(unsigned(range_to_cache.high));
    constant cache_range : natural := cache_range_high - cache_range_low;
    constant cache_range_log2 : natural := integer(ceil(log2(real(cache_range))));
    constant tag_size : natural := cache_range_log2 - cache_word_count_log2b + bus_byte_size_log2b - bus_address_width_log2b;

    signal transaction_required : boolean := false;
    signal read_stall : boolean := false;
    signal write_stall : boolean := false;
    signal dcache_updating_from_bus : boolean := false;
    signal corrected_byte_mask : riscv32_byte_mask_type;

    signal mst2slv_buf : bus_mst2slv_type := BUS_MST2SLV_IDLE;

    -- Read cache, volatile
    signal volatile_read_cache_data : riscv32_data_type;
    signal volatile_read_cache_miss : boolean := false;

    -- Write cache, volatile
    signal volatile_write_cache_miss : boolean := false;

    -- Data cache
    signal dcache_address_in : riscv32_address_type;
    signal dcache_data_out : riscv32_data_type;
    signal dcache_data_in : riscv32_data_type;
    signal dcache_byte_mask : riscv32_byte_mask_type;
    signal dcache_do_write : boolean;
    signal dcache_miss : boolean;
    signal dcache_significant_hit : boolean;
    signal address_in_dcache_range : boolean;
    signal dcache_reset : std_logic;

    -- Unaligned access handling
    signal unaligned_access : boolean := false;
begin
    address_in_dcache_range <= bus_addr_in_range(address, range_to_cache);
    dcache_significant_hit <= address_in_dcache_range and not dcache_miss;

    handle_read_stall : process(address_in_dcache_range, dcache_miss, volatile_read_cache_miss, doRead)
    begin
        if doRead then
            if address_in_dcache_range then
                read_stall <= dcache_miss;
            else
                read_stall <= volatile_read_cache_miss;
            end if;
        else
            read_stall <= false;
        end if;
    end process;

    write_stall <= volatile_write_cache_miss and doWrite;
    mst2slv <= mst2slv_buf;
    unaligned_access <= unsigned(address(riscv32_address_width_log2b - riscv32_byte_width_log2b - 1 downto 0)) > 0 and (doRead or doWrite);
    transaction_required <= read_stall or write_stall;
    stall <= transaction_required or unaligned_access;

    dcache_reset <= '1' when flushCache or rst else '0';

    data_out_handling : process(address_in_dcache_range, dcache_data_out, volatile_read_cache_data)
    begin
        if address_in_dcache_range then
            dataOut <= dcache_data_out;
        else
            dataOut <= volatile_read_cache_data;
        end if;
    end process;

    correct_for_dcache : process(byteMask, address_in_dcache_range, dcache_miss, doRead)
    begin
        if address_in_dcache_range and dcache_miss and doRead then
            corrected_byte_mask <= (others => '1');
        else
            corrected_byte_mask <= byteMask;
        end if;
    end process;

    volatile_read_cache : process(clk, address, byteMask)
        variable cache_valid : boolean := false;
        variable cache_address : riscv32_address_type;
        variable cache_data : riscv32_data_type;
        variable cache_byteMask : riscv32_byte_mask_type;
    begin
        if rising_edge(clk) then
            if read_transaction(mst2slv_buf, slv2mst) then
                cache_valid := true;
                cache_address := mst2slv_buf.address;
                cache_data := slv2mst.readData;
                cache_byteMask := mst2slv_buf.byteMask;
            elsif not doRead or flushCache then
                cache_valid := false;
            end if;
        end if;

        volatile_read_cache_miss <= not cache_valid or cache_address /= address or cache_byteMask /= byteMask;
        volatile_read_cache_data <= cache_data;
    end process;

    volatile_write_cache : process(clk, address, dataIn, byteMask)
        variable cache_valid : boolean := false;
        variable cache_address : riscv32_address_type;
        variable cache_data : riscv32_data_type;
        variable cache_byteMask : riscv32_byte_mask_type;
    begin
        if rising_edge(clk) then
            if write_transaction(mst2slv_buf, slv2mst) then
                cache_valid := true;
                cache_address := mst2slv_buf.address;
                cache_data := mst2slv_buf.writeData;
                cache_byteMask := mst2slv_buf.byteMask;
            elsif not doWrite or flushCache then
                cache_valid := false;
            end if;
        end if;

        volatile_write_cache_miss <= not cache_valid or cache_address /= address or cache_byteMask /= byteMask or cache_data /= dataIn;
    end process;

    dcache_controller : process(clk, address, byteMask, dcache_significant_hit, doWrite, dataIn)
        variable override_inputs : boolean := false;
        variable overriding_data_in : riscv32_data_type;
        variable overriding_write : boolean;
    begin
        if rising_edge(clk) then
            if read_transaction(mst2slv_buf, slv2mst) then
                override_inputs := true;
                overriding_data_in := slv2mst.readData;
                overriding_write := address_in_dcache_range;
            else
                override_inputs := false;
            end if;
        end if;
        dcache_updating_from_bus <= override_inputs;
        dcache_address_in <= address;
        if override_inputs then
            dcache_byte_mask <= (others => '1');
            dcache_do_write <= overriding_write;
            dcache_data_in <= overriding_data_in;
        else
            dcache_byte_mask <= byteMask;
            dcache_do_write <= dcache_significant_hit and doWrite;
            dcache_data_in <= dataIn;
        end if;
    end process;

    bus_handling : process(clk)
        variable hasFault_buf : boolean := false;
        variable bus_active : boolean := false;
    begin
        if rising_edge(clk) then
            if rst then
                mst2slv_buf <= BUS_MST2SLV_IDLE;
                hasFault_buf := false;
                bus_active := false;
            elsif any_transaction(mst2slv_buf, slv2mst) then
                if fault_transaction(mst2slv_buf, slv2mst) then
                    hasFault_buf := true;
                    faultData <= slv2mst.faultData;
                else
                    bus_active := false;
                end if;
                mst2slv_buf <= BUS_MST2SLV_IDLE;
            elsif transaction_required and not bus_active and not hasFault_buf and not forbidBusInteraction and not dcache_updating_from_bus then
                bus_active := true;
                if doRead then
                    mst2slv_buf <= bus_mst2slv_read(address, corrected_byte_mask);
                elsif doWrite then
                    mst2slv_buf <= bus_mst2slv_write(address, dataIn, corrected_byte_mask);
                end if;
            elsif unaligned_access then
                hasFault_buf := true;
                faultData <= bus_fault_unaligned_access;
            end if;

        end if;
        hasFault <= hasFault_buf;
    end process;

    dache : entity work.riscv32_dcache
    generic map (
        word_count_log2b => cache_word_count_log2b,
        tag_size => tag_size
    ) port map (
        clk => clk,
        rst => dcache_reset,
        addressIn => dcache_address_in,
        dataIn => dcache_data_in,
        dataOut => dcache_data_out,
        byteMask => dcache_byte_mask,
        doWrite => dcache_do_write,
        miss => dcache_miss,
        resetDirty => true
    );

end architecture;
