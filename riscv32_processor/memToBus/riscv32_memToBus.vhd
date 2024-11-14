library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;
use work.riscv32_pkg.all;

entity riscv32_memToBus is
    generic (
        range_to_cache : addr_range_type;
        cache_word_count_log2b : natural
    );
    port (
        clk : in std_logic;
        rst : in boolean;

        flush_cache : in boolean;
        cache_flush_busy : out boolean;

        mst2slv : out bus_mst2slv_type;
        slv2mst : in bus_slv2mst_type;

        hasFault : out boolean;

        address : in riscv32_address_type;
        byteMask : in riscv32_byte_mask_type;
        dataIn : in riscv32_data_type;
        doWrite : in boolean;
        doRead : in boolean;
        stallIn : in boolean;

        dataOut : out riscv32_data_type;
        stallOut : out boolean
    );
end entity;

architecture behaviourial of riscv32_memToBus is
    constant cache_range_low : natural := to_integer(unsigned(range_to_cache.low));
    constant cache_range_high : natural := to_integer(unsigned(range_to_cache.high));
    constant cache_range : natural := cache_range_high - cache_range_low;

    type state_type is (idle, cached_read_busy, uncached_read_busy, cached_write_busy, uncached_write_busy, cache_flushing);
    signal current_state : state_type := idle;
    signal next_state : state_type := idle;
    signal state_forces_stall : boolean := false;

    signal address_in_dcache_range : boolean;
    signal cached_read_required : boolean;
    signal uncached_read_required : boolean;
    signal write_from_proc_required : boolean;

    signal byteMask_indicates_full_word : boolean := false;

    signal fsm_write_busy : boolean := false;

    signal interactor_busy : boolean;
    signal interactor_completed : boolean;
    signal interactor_fault : boolean;
    signal interactor_doWrite : boolean := false;
    signal interactor_doRead : boolean := false;
    signal interactor_dataOut : bus_data_type;
    signal interactor_dataIn : bus_data_type;
    signal interactor_should_write_cached : boolean := false;
    signal interactor_should_write_uncached : boolean := false;
    signal interactor_writeAddress : bus_address_type;
    signal interactor_writeByteMask : bus_byte_mask_type;
    signal interactor_readByteMask : bus_byte_mask_type;

    signal cache_doWrite_fromProc : boolean;
    signal cache_doWrite_fromBus : boolean;

    signal cache_reconstructedAddr : bus_aligned_address_type;
    signal cache_line_dirty : boolean;
    signal cache_miss : boolean;
    signal cache_dataOut : riscv32_data_type;
    signal cache_reset : boolean := false;

    signal volatile_cache_data : bus_data_type;
    signal volatile_read_cache_valid : boolean := false;
    signal volatile_write_cache_valid : boolean := false;
    signal volatile_cache_update_read : boolean;
    signal volatile_cache_update_write : boolean;

    signal cache_flush_allowed : boolean := false;
    signal cache_flush_required : boolean := false;
    signal cache_flush_address : natural range 0 to 2**cache_word_count_log2b - 1;
    signal cache_flush_reconstructedAddr : bus_aligned_address_type;
    signal cache_flush_line_data_out : bus_data_type;
    signal cache_flush_line_dirty : boolean;
    signal cache_flush_write_required : boolean;
begin
    address_in_dcache_range <= bus_addr_in_range(address, range_to_cache);
    cached_read_required <= doRead and address_in_dcache_range and cache_miss;
    uncached_read_required <= doRead and not address_in_dcache_range and not volatile_read_cache_valid;
    byteMask_indicates_full_word <= byteMask = "1111";
    cache_flush_busy <= cache_flush_required;

    state_machine_output : process (current_state, cache_miss, interactor_completed, doRead, cached_read_required, uncached_read_required, interactor_should_write_cached, interactor_should_write_uncached, cache_flush_required, cache_flush_write_required)
    begin
        next_state <= current_state;
        case current_state is
            when idle =>
                state_forces_stall <= false;
                cache_doWrite_fromBus <= false;
                interactor_doWrite <= interactor_should_write_cached or interactor_should_write_uncached;
                interactor_doRead <= cached_read_required or uncached_read_required;
                volatile_cache_update_read <= false;
                fsm_write_busy <= false;
                cache_flush_allowed <= false;
                if cached_read_required then
                    next_state <= cached_read_busy;
                elsif uncached_read_required then
                    next_state <= uncached_read_busy;
                elsif interactor_should_write_uncached then
                    next_state <= uncached_write_busy;
                elsif interactor_should_write_cached then
                    next_state <= cached_write_busy;
                elsif cache_flush_required then
                    next_state <= cache_flushing;
                end if;
            when cached_read_busy =>
                state_forces_stall <= true;
                cache_doWrite_fromBus <= interactor_completed;
                interactor_doWrite <= interactor_should_write_cached;
                interactor_doRead <= false;
                volatile_cache_update_read <= false;
                fsm_write_busy <= false;
                cache_flush_allowed <= false;
                if interactor_completed and interactor_should_write_cached then
                    next_state <= cached_write_busy;
                elsif interactor_completed then
                    next_state <= idle;
                end if;
            when uncached_read_busy =>
                state_forces_stall <= true;
                cache_doWrite_fromBus <= false;
                interactor_doWrite <= false;
                interactor_doRead <= false;
                volatile_cache_update_read <= interactor_completed;
                fsm_write_busy <= false;
                cache_flush_allowed <= false;
                if interactor_completed then
                    next_state <= idle;
                end if;
            when cached_write_busy =>
                state_forces_stall <= false;
                cache_doWrite_fromBus <= false;
                interactor_doWrite <= false;
                interactor_doRead <= false;
                volatile_cache_update_write <= interactor_completed;
                fsm_write_busy <= true;
                cache_flush_allowed <= false;
                if interactor_completed then
                    next_state <= idle;
                end if;
            when uncached_write_busy =>
                state_forces_stall <= true;
                cache_doWrite_fromBus <= false;
                interactor_doWrite <= false;
                interactor_doRead <= false;
                volatile_cache_update_write <= interactor_completed;
                fsm_write_busy <= true;
                cache_flush_allowed <= false;
                if interactor_completed then
                    next_state <= idle;
                end if;
            when cache_flushing =>
                state_forces_stall <= true;
                cache_doWrite_fromBus <= false;
                interactor_doWrite <= cache_flush_write_required;
                interactor_doRead <= false;
                volatile_cache_update_read <= false;
                fsm_write_busy <= false;
                cache_flush_allowed <= true;
                if not cache_flush_required then
                    next_state <= idle;
                end if;
        end case;
    end process;

    state_machine_next : process(clk)
    begin
        if rising_edge(clk) then
            if rst then
                current_state <= idle;
            else
                current_state <= next_state;
            end if;
        end if;
    end process;

    determine_stallout : process(cache_miss, doRead, state_forces_stall, address_in_dcache_range, volatile_read_cache_valid, interactor_busy, interactor_should_write_cached, fsm_write_busy, flush_cache, cache_flush_required)
    begin
        stallOut <= false;
        if state_forces_stall then
            stallOut <= true;
        elsif flush_cache or cache_flush_required then
            stallOut <= true;
        elsif doRead then
            if address_in_dcache_range then
                stallOut <= cache_miss;
            else
                stallOut <= not volatile_read_cache_valid;
            end if;
        elsif doWrite then
            if address_in_dcache_range then
                stallOut <= interactor_should_write_cached and fsm_write_busy;
            else
                stallOut <= interactor_should_write_uncached;
            end if;
        end if;
    end process;

    volatile_cache : process(clk)
    begin
        if rising_edge(clk) then
            if rst then
                volatile_read_cache_valid <= false;
                volatile_write_cache_valid <= false;
                hasFault <= false;
            elsif volatile_cache_update_read then
                volatile_cache_data <= interactor_dataOut;
                volatile_read_cache_valid <= true;
                hasFault <= interactor_fault;
            elsif volatile_cache_update_write then
                volatile_write_cache_valid <= true;
                hasFault <= interactor_fault;
            elsif not stallIn then
                volatile_read_cache_valid <= false;
                volatile_write_cache_valid <= false;
                hasFault <= false;
            end if;
        end if;
    end process;

    determine_interactor_readByteMask : process(byteMask, address_in_dcache_range, doRead)
    begin
        if doRead and address_in_dcache_range then
            interactor_readByteMask <= (others => '1');
        else
            interactor_readByteMask <= byteMask;
        end if;
    end process;

    determine_data_out : process(address_in_dcache_range, cache_dataOut, volatile_cache_data)
    begin
        if address_in_dcache_range then
            dataOut <= cache_dataOut;
        else
            dataOut <= volatile_cache_data;
        end if;
    end process;

    determine_interactor_write_in : process(byteMask_indicates_full_word, cache_miss, cache_line_dirty, doWrite, doRead, cache_reconstructedAddr, cache_dataOut, dataIn, address, volatile_write_cache_valid, fsm_write_busy, address_in_dcache_range, cache_flush_reconstructedAddr, cache_flush_line_data_out, cache_flush_allowed)
    begin
        -- Cover all default cases
        interactor_should_write_cached <= false;
        interactor_should_write_uncached <= false;
        cache_doWrite_fromProc <= false;
        interactor_writeByteMask <= byteMask;
        interactor_dataIn <= dataIn;
        interactor_writeAddress <= address;
        if cache_flush_allowed then
            interactor_should_write_cached <= false;
            interactor_should_write_uncached <= false;
            cache_doWrite_fromProc <= false;
            interactor_writeByteMask <= (others => '1');
            interactor_dataIn <= cache_flush_line_data_out;
            interactor_writeAddress <= cache_flush_reconstructedAddr & "00";
        elsif doWrite and address_in_dcache_range then
            -- Proc writes full word to a clean cache line, memory requires no update
            if byteMask_indicates_full_word and not cache_line_dirty then
                interactor_should_write_cached <= false;
                interactor_should_write_uncached <= false;
                cache_doWrite_fromProc <= true;
                interactor_writeByteMask <= byteMask;
                interactor_dataIn <= dataIn;
                interactor_writeAddress <= address;
            -- Proc writes partial data to cached word, just update the cache.
            elsif not byteMask_indicates_full_word and not cache_miss then
                interactor_should_write_cached <= false;
                interactor_should_write_uncached <= false;
                cache_doWrite_fromProc <= true;
                interactor_writeByteMask <= byteMask;
                interactor_dataIn <= dataIn;
                interactor_writeAddress <= address;
            -- Proc overwrites existing and dirty cache line. Dirty cache line needs to be forwarded to memory
            elsif byteMask_indicates_full_word and cache_miss and cache_line_dirty then
                interactor_should_write_cached <= true;
                interactor_should_write_uncached <= false;
                cache_doWrite_fromProc <= not fsm_write_busy;
                interactor_writeByteMask <= (others => '1');
                interactor_dataIn <= cache_dataOut;
                interactor_writeAddress <= cache_reconstructedAddr & "00";
            -- Proc writes partial data to uncached word, we have to commit to memory. Act as if it is a write to out-of-cache-range memory
            elsif not byteMask_indicates_full_word and cache_miss then
                interactor_should_write_cached <= not volatile_write_cache_valid;
                interactor_should_write_uncached <= false;
                cache_doWrite_fromProc <= false;
                interactor_writeByteMask <= byteMask;
                interactor_dataIn <= dataIn;
                interactor_writeAddress <= address;
            end if;
        elsif doWrite and not address_in_dcache_range then
            interactor_should_write_cached <= false;
            interactor_should_write_uncached <= not volatile_write_cache_valid;
            cache_doWrite_fromProc <= false;
            interactor_writeByteMask <= byteMask;
            interactor_dataIn <= dataIn;
            interactor_writeAddress <= address;
        elsif doRead and address_in_dcache_range then
            -- Dirty line needs to be comitted to memory
            if cache_miss and cache_line_dirty then
                interactor_should_write_cached <= true;
                interactor_should_write_uncached <= false;
                cache_doWrite_fromProc <= false;
                interactor_writeByteMask <= (others => '1');
                interactor_dataIn <= cache_dataOut;
                interactor_writeAddress <= cache_reconstructedAddr & "00";
            end if;
        end if;
    end process;

    cache_flusher : process(clk)
        type flush_state_type is (idle, flush_requested, reading_data, decide_write, wait_for_interactor, increment_address, completing);
        variable flush_cur_state : flush_state_type := idle;
        variable flush_next_state : flush_state_type := idle;
        variable cache_line_address : natural range 0 to 2**cache_word_count_log2b - 1 := 0;
    begin
        if rising_edge(clk) then
            if rst then
                flush_cur_state := idle;
            else
                flush_cur_state := flush_next_state;
            end if;
            case flush_cur_state is
                when idle =>
                    cache_line_address := 0;
                    cache_flush_required <= flush_cache;
                    cache_flush_write_required <= false;
                    cache_reset <= false;
                    if flush_cache then
                        flush_next_state := flush_requested;
                    end if;
                when flush_requested =>
                    cache_line_address := 0;
                    cache_flush_required <= true;
                    cache_flush_write_required <= false;
                    cache_reset <= false;
                    if cache_flush_allowed then
                        flush_next_state := reading_data;
                    end if;
                when reading_data =>
                    cache_flush_required <= true;
                    cache_flush_write_required <= false;
                    cache_reset <= false;
                    flush_next_state := decide_write;
                when decide_write =>
                    cache_flush_required <= true;
                    cache_reset <= false;
                    if cache_flush_line_dirty then
                        cache_flush_write_required <= true;
                        flush_next_state := wait_for_interactor;
                    else
                        cache_flush_write_required <= false;
                        flush_next_state := increment_address;
                    end if;
                when wait_for_interactor =>
                    cache_flush_required <= true;
                    cache_flush_write_required <= false;
                    cache_reset <= false;
                    if interactor_completed then
                        flush_next_state := increment_address;
                    end if;
                when increment_address =>
                    cache_flush_required <= true;
                    cache_flush_write_required <= false;
                    cache_reset <= false;
                    if cache_line_address = 2**cache_word_count_log2b - 1 then
                        flush_next_state := completing;
                    else
                        cache_line_address := cache_line_address + 1;
                        flush_next_state := reading_data;
                    end if;
                when completing =>
                    cache_flush_required <= true;
                    cache_flush_write_required <= false;
                    cache_reset <= true;
                    flush_next_state := idle;
            end case;
            flush_cur_state := flush_next_state;
        end if;
        cache_flush_address <= cache_line_address;
    end process;

    interactor : entity work.riscv32_memToBus_bus_interaction
    port map (
        clk => clk,
        rst => rst,

        mst2slv => mst2slv,
        slv2mst => slv2mst,

        readAddress => address,
        writeAddress => interactor_writeAddress,
        readByteMask => interactor_readByteMask,
        writeByteMask => interactor_writeByteMask,
        doRead => interactor_doRead,
        doWrite => interactor_doWrite,
        dataIn => interactor_dataIn,

        busy => interactor_busy,
        completed => interactor_completed,
        fault => interactor_fault,
        dataOut => interactor_dataOut
    );

    dcache : entity work.riscv32_write_back_dcache
    generic map (
        word_count_log2b => cache_word_count_log2b,
        cache_range_size => cache_range,
        cached_base_address => range_to_cache.low(bus_aligned_address_type'range)
    ) port map (
        clk => clk,
        rst => rst or cache_reset,
        addressIn => address(bus_aligned_address_type'range),
        proc_dataIn => dataIn,
        proc_byteMask => byteMask,
        proc_doWrite => cache_doWrite_fromProc,
        bus_dataIn => interactor_dataOut,
        bus_doWrite => cache_doWrite_fromBus,
        dataOut => cache_dataOut,
        reconstructedAddr => cache_reconstructedAddr,
        dirty => cache_line_dirty,
        miss => cache_miss,
        line_address => cache_flush_address,
        line_reconstructedAddr => cache_flush_reconstructedAddr,
        line_dataOut => cache_flush_line_data_out,
        line_dirty => cache_flush_line_dirty
    );
end architecture;
