library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;

entity bus_cache_frontend is
    port (
        clk : in std_logic;
        rst : in boolean;

        mst2frontend : in bus_mst2slv_type;
        frontend2mst : out bus_slv2mst_type;

        address : out bus_address_type;
        byte_mask : out bus_byte_mask_type;
        data_out : out bus_data_type;
        data_in : in bus_data_type;
        is_read : out boolean;
        is_write : out boolean;

        complete_transaction : in boolean;
        error_transaction : in boolean;
        fault_data : in bus_fault_type
    );
end entity;

architecture behaviourial of bus_cache_frontend is
    type state_type is (idle, read_pending, write_pending, transaction_completing);

    signal cur_state : state_type := idle;
    signal next_state : state_type := idle;

    signal mst2fronted_buf : bus_mst2slv_type;

    signal finish_transaction : boolean;
begin
    finish_transaction <= complete_transaction or error_transaction;
    buf_mst2frontend : process(clk)
    begin
        if rising_edge(clk) then
            mst2fronted_buf <= mst2frontend;
        end if;
    end process;

    state_machine_sequential : process(clk)
    begin
        if rising_edge(clk) then
            if rst then
                cur_state <= idle;
            else
                cur_state <= next_state;
            end if;
        end if;
    end process;

    frontend_to_mst : process(clk)
    begin
        if rising_edge(clk) then
            frontend2mst.readData <= data_in;
            frontend2mst.valid <= complete_transaction;
            frontend2mst.faultData <= fault_data;
            frontend2mst.fault <= '1' when error_transaction else '0';
        end if;
    end process;

    state_machine_combinatoral : process(cur_state, mst2frontend, mst2fronted_buf, finish_transaction)
    begin
        next_state <= cur_state;
        case cur_state is
            when idle =>
                address <= (others => '-');
                byte_mask <= (others => '-');
                data_out <= (others => '-');
                is_read <= false;
                is_write <= false;
                if mst2frontend.readReady = '1' then
                    next_state <= read_pending;
                elsif mst2frontend.writeReady = '1' then
                    next_state <= write_pending;
                end if;
            when read_pending =>
                address <= mst2fronted_buf.address;
                byte_mask <= mst2fronted_buf.byteMask;
                data_out <= (others => '-');
                is_read <= true;
                is_write <= false;
                if finish_transaction then
                    next_state <= transaction_completing;
                end if;
            when write_pending =>
                address <= mst2fronted_buf.address;
                byte_mask <= mst2fronted_buf.byteMask;
                data_out <= mst2fronted_buf.writeData;
                is_read <= false;
                is_write <= true;
                if finish_transaction then
                    next_state <= transaction_completing;
                end if;
            when transaction_completing =>
                address <= (others => '-');
                byte_mask <= (others => '-');
                data_out <= (others => '-');
                is_read <= false;
                is_write <= false;
                next_state <= idle;
        end case;
    end process;

end architecture;
