library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library src;
use src.bus_pkg.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
use vunit_lib.sync_pkg.all;

library tb;
use tb.simulated_bus_memory_pkg.all;

entity simulated_bus_memory is
    generic (
        constant depth_log2b : natural range bus_bytes_per_word_log2b to natural'high;
        constant allow_unaligned_access : boolean;
        constant actor : actor_t;
        constant read_delay : natural := 0;
        constant write_delay : natural := 0;
        constant logger : logger_t := get_logger("simulated_bus_memory");
        constant checker : checker_t := new_checker("simulated_bus_memory checker")
    );
    port (
        clk : in std_logic;
        mst2mem : in bus_mst2slv_type;
        mem2mst : out bus_slv2mst_type
    );
end simulated_bus_memory;

architecture behavioral of simulated_bus_memory is
    signal last_mst2mem_request : bus_mst2slv_type := BUS_MST2SLV_IDLE;
    constant byte_count : natural := 2**DEPTH_LOG2B;

    signal ram : bus_byte_array(0 to byte_count - 1);

    signal read_delay_left : natural := read_delay;
    signal write_delay_left : natural := write_delay;
    signal mem2mst_internal : bus_slv2mst_type;

    signal vcom_request_write : std_logic := '0';
    signal vcom_write_done : boolean := false;
    signal vcom_request_address : bus_address_type;
    signal vcom_request_data : bus_data_type;
    signal vcom_request_byteMask : bus_byte_mask_type;

begin
    mem2mst <= mem2mst_internal;
    msg_handler : process is
        variable request_msg, reply_msg : msg_t;
        variable msg_type : msg_type_t;
        variable return_data : bus_data_type;
        variable address : bus_address_type;
        variable mask : bus_byte_mask_type;
        variable input_data : bus_data_type;
    begin
        receive(net, actor, request_msg);
        msg_type := message_type(request_msg);
        handle_sync_message(net, msg_type, request_msg);

        if msg_type = read_lastMasterReq_msg then
            reply_msg := new_msg(read_reply_msg);
            push(reply_msg, last_mst2mem_request.address);
            push(reply_msg, last_mst2mem_request.writeData);
            push(reply_msg, last_mst2mem_request.byteMask);
            push(reply_msg, last_mst2mem_request.readReady);
            push(reply_msg, last_mst2mem_request.writeReady);
            push(reply_msg, last_mst2mem_request.burst);
            reply(net, request_msg, reply_msg);
        elsif msg_type = read_fromAddress_msg then
            reply_msg := new_msg(read_reply_msg);
            address := pop(request_msg);
            for i in 0 to bus_bytes_per_word - 1 loop
                return_data((i+1)*bus_byte_type'length - 1 downto i*bus_byte_type'length) := ram(to_integer(unsigned(address)) + i);
            end loop;
            push(reply_msg, return_data);
            reply(net, request_msg, reply_msg);
        elsif msg_type = write_toAddress_msg then
            vcom_request_address <= pop(request_msg);
            vcom_request_data <= pop(request_msg);
            vcom_request_byteMask <= pop(request_msg);
            vcom_request_write <= '1';
            wait until vcom_write_done;
            vcom_request_write <= '0';
            wait until not vcom_write_done;
        else
            unexpected_msg_type(msg_type);
        end if;
    end process;

    bus_output_handling : process(mst2mem, read_delay_left, write_delay_left)
        variable address : natural;
    begin
        mem2mst_internal <= BUS_SLV2MST_IDLE;
        if bus_requesting(mst2mem) then
            -- Check for faults
            address := to_integer(unsigned(mst2mem.address));
            if not(allow_unaligned_access or bus_addr_is_aligned_to_bus(mst2mem.address)) then
                mem2mst_internal.fault <= '1';
                mem2mst_internal.faultData <= bus_fault_unaligned_access;
            elsif address > ram'high then
                mem2mst_internal.fault <= '1';
                mem2mst_internal.faultData <= bus_fault_address_out_of_range;
            end if;

            if mem2mst_internal.fault = '1' then
                info(logger, "Fault transaction for address " & to_hstring(mst2mem.address) & " fault is " & to_hstring(mem2mst_internal.faultData));
            end if;

            if mst2mem.readReady = '1' and read_delay_left = 0 then
                mem2mst_internal.valid <= true;
                for i in 0 to bus_bytes_per_word - 1 loop
                    mem2mst_internal.readData((i+1)*bus_byte_type'length - 1 downto i*bus_byte_type'length) <= ram(address + i);
                end loop;
            elsif mst2mem.writeReady = '1' and write_delay_left = 0 then
                mem2mst_internal.valid <= true;
            end if;
        end if;
    end process;

    bus_delay_handling : process(clk)
    begin
        if rising_edge(clk) then
            if bus_requesting(mst2mem) then
                if read_delay_left > 0 then
                    read_delay_left <= read_delay_left - 1;
                end if;
                if write_delay_left > 0 then
                    write_delay_left <= write_delay_left - 1;
                end if;
            end if;

            if any_transaction(mst2mem, mem2mst_internal) then
                write_delay_left <= write_delay;
                read_delay_left <= read_delay;
            end if;
        end if;
    end process;

    data_write_handling : process(clk, vcom_request_write)
    begin
        if rising_edge(vcom_request_write) then
            for i in 0 to bus_bytes_per_word - 1 loop
                if vcom_request_byteMask(i) = '1' then
                    ram(to_integer(unsigned(vcom_request_address)) + i) <= vcom_request_data((i+1)*bus_byte_type'length - 1 downto i*bus_byte_type'length);
                end if;
            end loop;
            vcom_write_done <= true;
        else
            vcom_write_done <= false;
        end if;

        if rising_edge(clk) then
            if write_transaction(mst2mem, mem2mst_internal) then
                for i in 0 to bus_bytes_per_word - 1 loop
                    if mst2mem.byteMask(i) = '1' then
                        ram(to_integer(unsigned(mst2mem.address)) + i) <= mst2mem.writeData((i+1)*bus_byte_type'length - 1 downto i*bus_byte_type'length);
                    end if;
                end loop;
            end if;
        end if;
    end process;

    master_sanity_checker : process(clk)
        variable allow_master_change : boolean := true;
        variable burst_was_active : boolean := false;
    begin
        if rising_edge(clk) then
            check(checker, mst2mem.readReady = '0' or mst2mem.writeReady = '0', "Master cannot set readReady and writeReady high at the same time!");
            check(checker, allow_master_change or last_mst2mem_request = mst2mem, "Master cannot change mst2mem until the slave has acknowledged!");
            if bus_requesting(mst2mem) then
                if allow_master_change then
                    allow_master_change := false;
                    last_mst2mem_request <= mst2mem;
                    if mst2mem.burst = '1' then
                        burst_was_active := true;
                    else
                        burst_was_active := false;
                    end if;
                end if;

                if any_transaction(mst2mem, mem2mst_internal) then
                    allow_master_change := true;
                end if;

                if fault_transaction(mst2mem, mem2mst_internal) then
                    burst_was_active := false;
                end if;
            elsif burst_was_active then
                check(checker, mst2mem.burst = '1', "Master can only drop burst whenever a request comes in!");
            elsif not burst_was_active then
                check(checker, mst2mem.burst /= '1', "Master can only raise burst whenever a request comes in!");
            end if;
        end if;
    end process;
end architecture;
