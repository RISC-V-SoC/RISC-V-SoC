library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

library src;
use src.bus_pkg;

package simulated_bus_memory_pkg is
    constant read_reply_msg : msg_type_t := new_msg_type("read reply");

    constant read_lastMasterReq_msg     : msg_type_t := new_msg_type("read last master request");

    constant read_fromAddress_msg : msg_type_t := new_msg_type("read from address");
    constant write_toAddress_msg : msg_type_t := new_msg_type("write to address");

    procedure read_lastMasterReq(
              signal net : inout network_t;
              constant actor : in actor_t;
              variable data : out bus_pkg.bus_mst2slv_type);

    procedure read_from_address(
              signal net : inout network_t;
              constant actor : in actor_t;
              constant addr : in bus_pkg.bus_address_type;
              variable data : out bus_pkg.bus_data_type);

    procedure read_from_address(
              signal net : inout network_t;
              constant actor : in actor_t;
              constant addr : in bus_pkg.bus_address_type;
              variable data : out bus_pkg.bus_data_array);

    procedure write_to_address(
              signal net : inout network_t;
              constant actor : in actor_t;
              constant addr : in bus_pkg.bus_address_type;
              constant data : in bus_pkg.bus_data_type;
              constant mask : in bus_pkg.bus_byte_mask_type);

    procedure write_to_address(
              signal net : inout network_t;
              constant actor : in actor_t;
              constant addr : in bus_pkg.bus_address_type;
              constant data : in bus_pkg.bus_data_array;
              constant mask : in bus_pkg.bus_byte_mask_type);

    procedure write_file_to_address (
              signal net : inout network_t;
              constant actor : in actor_t;
              constant addr : in natural;
              constant fileName : in string);
end package;

package body simulated_bus_memory_pkg is

    procedure read_lastMasterReq(
              signal net : inout network_t;
              constant actor : in actor_t;
              variable data : out bus_pkg.bus_mst2slv_type) is
        variable msg : msg_t := new_msg(read_lastMasterReq_msg);
        variable reply_msg : msg_t;
    begin
        request(net, actor, msg, reply_msg);
        data.address := pop(reply_msg);
        data.writeData := pop(reply_msg);
        data.byteMask := pop(reply_msg);
        data.readReady := pop(reply_msg);
        data.writeReady := pop(reply_msg);
        data.burst := pop(reply_msg);
    end;

    procedure read_from_address(
              signal net : inout network_t;
              constant actor : in actor_t;
              constant addr : in bus_pkg.bus_address_type;
              variable data : out bus_pkg.bus_data_type) is
        variable msg : msg_t := new_msg(read_fromaddress_msg);
        variable reply_msg : msg_t;
    begin
        push(msg, addr);
        request(net, actor, msg, reply_msg);
        data := pop(reply_msg);
    end;

    procedure read_from_address(
              signal net : inout network_t;
              constant actor : in actor_t;
              constant addr : in bus_pkg.bus_address_type;
              variable data : out bus_pkg.bus_data_array) is
        variable address_internal : natural;
        variable output_address : bus_pkg.bus_address_type;
    begin
        address_internal := to_integer(unsigned(addr));
        for i in 0 to data'length - 1 loop
            output_address := std_logic_vector(to_unsigned(address_internal + bus_pkg.bus_bytes_per_word*i, output_address'length));
            read_from_address(net => net,
                             actor => actor,
                             addr => output_address,
                             data => data(i));
        end loop;
    end;

    procedure write_to_address(
              signal net : inout network_t;
              constant actor : in actor_t;
              constant addr : in bus_pkg.bus_address_type;
              constant data : in bus_pkg.bus_data_type;
              constant mask : in bus_pkg.bus_byte_mask_type) is
        variable msg : msg_t := new_msg(write_toAddress_msg);
    begin
        push(msg, addr);
        push(msg, data);
        push(msg, mask);
        send(net, actor, msg);
    end;

    procedure write_to_address(
              signal net : inout network_t;
              constant actor : in actor_t;
              constant addr : in bus_pkg.bus_address_type;
              constant data : in bus_pkg.bus_data_array;
              constant mask : in bus_pkg.bus_byte_mask_type) is
        variable address_internal : natural;
        variable output_address : bus_pkg.bus_address_type;
    begin
        address_internal := to_integer(unsigned(addr));
        for i in 0 to data'length - 1 loop
            output_address := std_logic_vector(to_unsigned(address_internal + bus_pkg.bus_bytes_per_word*i, output_address'length));
            write_to_address(net => net,
                             actor => actor,
                             addr => output_address,
                             data => data(i),
                             mask => mask);
        end loop;
    end;

    procedure write_file_to_address(
              signal net : inout network_t;
              constant actor : in actor_t;
              constant addr : in natural;
              constant fileName : in string) is
        file read_file : text;
        variable line_v : line;
        variable data : bus_pkg.bus_data_type;
        variable address : natural := addr;
        variable busAddress : bus_pkg.bus_address_type;
        constant mask : bus_pkg.bus_byte_mask_type := (others => '1');
    begin
        file_open(read_file, fileName, read_mode);
        while not endfile(read_file) loop
            readline(read_file, line_v);
            hread(line_v, data);
            busAddress := std_logic_vector(to_unsigned(address, busAddress'length));
            write_to_address(net, actor, busAddress, data, mask);
            address := address + 4;
        end loop;
        file_close(read_file);
    end;

end package body;
