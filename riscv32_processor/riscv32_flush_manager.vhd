library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;
use work.riscv32_pkg.all;

entity riscv32_flush_manager is
    generic (
        external_memory_count : natural
    );
    port (
        clk : in std_logic;
        rst : in boolean;

        do_flush : in boolean;
        flush_busy : out boolean;

        dcache_do_flush : out boolean;
        dcache_flush_busy : in boolean;

        ext_do_flush : out boolean_vector(external_memory_count - 1 downto 0);
        ext_flush_busy : in boolean_vector(external_memory_count - 1 downto 0)
    );
end entity;

architecture behaviourial of riscv32_flush_manager is
    constant max_ext_mem_index : integer := external_memory_count - 1;
    type state_type is (idle, dcache_flush_start, dcache_flush_wait, ext_flush_start, ext_flush_wait);
    signal cur_state : state_type := idle;
    signal next_state : state_type := idle;

    signal ext_mem_index : natural range 0 to max_ext_mem_index := 0;

    signal selected_ext_mem_do_flush : boolean := false;
    signal selected_ext_mem_busy : boolean;
begin

    ext_mem_demuxer : process(ext_mem_index, selected_ext_mem_do_flush, ext_flush_busy)
    begin
        for i in 0 to external_memory_count - 1 loop
            if i = ext_mem_index then
                ext_do_flush(i) <= selected_ext_mem_do_flush;
                selected_ext_mem_busy <= ext_flush_busy(i);
            else
                ext_do_flush(i) <= false;
            end if;
        end loop;
    end process;

    ext_mem_index_counter : process(clk)
    begin
        if rising_edge(clk) and external_memory_count > 0 then
            if rst or cur_state = idle then
                ext_mem_index <= 0;
            elsif cur_state = ext_flush_wait and next_state = ext_flush_start and ext_mem_index < max_ext_mem_index then
                ext_mem_index <= ext_mem_index + 1;
            end if;
        end if;
    end process;

    cur_state_handling : process(clk)
    begin
        if rising_edge(clk) then
            if rst then
                cur_state <= idle;
            else
                cur_state <= next_state;
            end if;
        end if;
    end process;

    next_state_handling : process(cur_state, do_flush, dcache_flush_busy, ext_flush_busy, ext_mem_index, selected_ext_mem_busy)
    begin
        next_state <= cur_state;
        case cur_state is
            when idle =>
                if do_flush then
                    next_state <= dcache_flush_start;
                end if;
            when dcache_flush_start =>
                if dcache_flush_busy then
                    next_state <= dcache_flush_wait;
                end if;
            when dcache_flush_wait =>
                if not dcache_flush_busy then
                    if external_memory_count = 0 then
                        next_state <= idle;
                    else
                        next_state <= ext_flush_start;
                    end if;
                end if;
            when ext_flush_start =>
                if selected_ext_mem_busy then
                    next_state <= ext_flush_wait;
                end if;
            when ext_flush_wait =>
                if not selected_ext_mem_busy then
                    if ext_mem_index = external_memory_count - 1 then
                        next_state <= idle;
                    else
                        next_state <= ext_flush_start;
                    end if;
                end if;
        end case;
    end process;

    state_output : process(cur_state, ext_mem_index)
    begin
        case cur_state is
            when idle =>
                flush_busy <= false;
                dcache_do_flush <= false;
                selected_ext_mem_do_flush <= false;
            when dcache_flush_start =>
                flush_busy <= true;
                dcache_do_flush <= true;
                selected_ext_mem_do_flush <= false;
            when dcache_flush_wait =>
                flush_busy <= true;
                dcache_do_flush <= false;
                selected_ext_mem_do_flush <= false;
            when ext_flush_start =>
                flush_busy <= true;
                dcache_do_flush <= false;
                selected_ext_mem_do_flush <= true;
            when ext_flush_wait =>
                flush_busy <= true;
                dcache_do_flush <= false;
                selected_ext_mem_do_flush <= false;
        end case;
    end process;
end architecture;
