library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.math_real.all;

library work;
use work.bus_pkg.all;
use work.riscv32_pkg.all;

entity riscv32_if2bus is
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
        exception_code : out riscv32_exception_code_type;
        faultData : out bus_fault_type;

        requestAddress : in riscv32_address_type;
        instruction : out riscv32_instruction_type;
        stall : out boolean
    );
end entity;

architecture behaviourial of riscv32_if2bus is
    constant cache_range_low : natural := to_integer(unsigned(range_to_cache.low));
    constant cache_range_high : natural := to_integer(unsigned(range_to_cache.high));
    constant cache_range : natural := cache_range_high - cache_range_low;
    constant cache_range_log2 : natural := integer(ceil(log2(real(cache_range))));
    constant tag_size : natural := cache_range_log2 - cache_word_count_log2b + bus_byte_size_log2b - bus_address_width_log2b;

    signal instruction_from_bus : riscv32_instruction_type;
    signal icache_write : boolean := false;
    signal icache_miss : boolean;
    signal icache_fault : boolean;
    signal icache_reset : std_logic;
    signal faulty_address : riscv32_address_type := (others => '0');
    signal hasFault_buf : boolean := false;
    signal output_fault : boolean := false;
begin
    hasFault <= output_fault;
    output_fault <= hasFault_buf and requestAddress = faulty_address;
    icache_fault <= not bus_addr_in_range(requestAddress, range_to_cache);
    stall <= (icache_miss or icache_fault) and not output_fault;
    icache_reset <= '1' when flushCache or rst else '0';
    exception_code <= riscv32_exception_code_instruction_access_fault;

    handleBus : process(clk)
        variable mst2slv_buf : bus_mst2slv_type := BUS_MST2SLV_IDLE;
        variable faultData_buf : bus_fault_type := bus_fault_no_fault;
        variable transactionFinished_buf : boolean := false;
    begin
        if rising_edge(clk) then
            transactionFinished_buf := false;
            if rst then
                mst2slv_buf := BUS_MST2SLV_IDLE;
                hasFault_buf <= false;
                faultData_buf := bus_fault_no_fault;
            else
                if icache_write then
                    icache_write <= false;
                elsif any_transaction(mst2slv_buf, slv2mst) then
                    if fault_transaction(mst2slv_buf, slv2mst) then
                        faulty_address <= requestAddress;
                        hasFault_buf <= true;
                        faultData_buf := slv2mst.faultData;
                    elsif read_transaction(mst2slv_buf, slv2mst) then
                        instruction_from_bus <= slv2mst.readData(instruction'range);
                        icache_write <= true;
                    end if;
                    mst2slv_buf := BUS_MST2SLV_IDLE;
                elsif hasFault_buf then
                    if faulty_address /= requestAddress then
                        hasFault_buf <= false;
                    end if;
                elsif forbidBusInteraction then
                    -- Pass
                elsif icache_miss and not icache_fault then
                    mst2slv_buf := bus_mst2slv_read(address => requestAddress);
                end if;

                if icache_fault then
                    hasFault_buf <= true;
                    faultData_buf := bus_fault_address_out_of_range;
                    faulty_address <= requestAddress;
                end if;

            end if;
        end if;
        mst2slv <= mst2slv_buf;
        faultData <= faultData_buf;
    end process;

    icache : entity work.riscv32_icache
    generic map (
        word_count_log2b => cache_word_count_log2b,
        tag_size => tag_size
    ) port map (
        clk => clk,
        rst => icache_reset,
        requestAddress => requestAddress,
        instructionOut => instruction,
        instructionIn => instruction_from_bus,
        doWrite => icache_write,
        miss => icache_miss
    );

end architecture;
