library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library tb;
use tb.M23LC1024_pkg.all;

library src;
use src.bus_pkg.all;

package triple_23lc1024_tb_pkg is
    procedure write_bus_word(
              signal net : inout network_t;
              constant actor : in actor_t;
              constant start_address : in std_logic_vector(16 downto 0);
              constant data : in bus_data_type);

    procedure read_bus_word(
            signal net : inout network_t;
            constant actor : in actor_t;
            constant start_address : in std_logic_vector(16 downto 0);
            variable data : out bus_data_type);

    procedure set_all_mode(constant expOp : in OperationMode;
                           constant expIo : in InoutMode;
                           constant actor : in actor_t;
                           signal net : inout network_t);

    procedure set_all_mode(constant expOp : in OperationMode;
                           constant expIo : in InoutMode;
                           constant actors : actor_vec_t;
                           signal net : inout network_t);

    procedure check_all_mode(constant expOp : in OperationMode;
                             constant expIo : in InoutMode;
                             constant actors : actor_vec_t;
                             signal net : inout network_t);

    pure function reorder_nibbles (
        word_in : bus_data_type
    ) return bus_data_type;
end triple_23lc1024_tb_pkg;

package body triple_23lc1024_tb_pkg is
    procedure write_bus_word(
              signal net : inout network_t;
              constant actor : in actor_t;
              constant start_address : in std_logic_vector(16 downto 0);
              constant data : in bus_data_type) is
        variable cur_address : std_logic_vector(16 downto 0) := start_address;
        variable data_shifter : bus_data_type := data;
    begin
        for i in 0 to 2**(bus_data_width_log2b - 3) - 1 loop
            info("cur_address " & to_hstring(cur_address));
            write_to_address(net, actor, cur_address, data_shifter(7 downto 0));
            cur_address := std_logic_vector(to_unsigned(to_integer(unsigned(cur_address)) + 1, cur_address'length));
            data_shifter := std_logic_vector(shift_right(unsigned(data_shifter), 8));
        end loop;
    end;

    procedure read_bus_word(
            signal net : inout network_t;
            constant actor : in actor_t;
            constant start_address : in std_logic_vector(16 downto 0);
            variable data : out bus_data_type) is
        variable cur_address : std_logic_vector(16 downto 0) := start_address;
    begin
        for i in 0 to 2**(bus_data_width_log2b - 3) - 1 loop
            info("cur_address " & to_hstring(cur_address));
            read_from_address(net, actor, cur_address, data((i*8) + 7 downto (i*8)));
            cur_address := std_logic_vector(to_unsigned(to_integer(unsigned(cur_address)) + 1, cur_address'length));
        end loop;
    end;

    procedure set_all_mode(constant expOp : in OperationMode;
                           constant expIo : in InoutMode;
                           constant actor : in actor_t;
                           signal net : inout network_t) is
    begin
        write_operationMode(net, actor, expOp);
        write_inoutMode(net, actor, expIo);
    end procedure;

    procedure set_all_mode(constant expOp : in OperationMode;
                           constant expIo : in InoutMode;
                           constant actors : actor_vec_t;
                           signal net : inout network_t) is
    begin
        for i in actors'range loop
            write_operationMode(net, actors(i), expOp);
            write_inoutMode(net, actors(i), expIo);
        end loop;
    end procedure;

    procedure check_all_mode(constant expOp : in OperationMode;
                             constant expIo : in InoutMode;
                             constant actors : actor_vec_t;
                             signal net : inout network_t) is
        variable received_opmode : OperationMode;
        variable received_iomode : InoutMode;
    begin
        for i in actors'range loop
            read_operationMode(net, actors(i), received_opmode);
            read_inoutMode(net, actors(i), received_iomode);
            check(received_opmode = expOp);
            check(received_iomode = expIo);
        end loop;
    end procedure;

    pure function reorder_nibbles (
        word_in : bus_data_type
    ) return bus_data_type is
    variable ret_val : bus_data_type;
    constant nibble_size : natural := bus_byte_size/2;
    begin
        for i in 0 to bus_bytes_per_word - 1 loop
           ret_val(nibble_size + i*bus_byte_size - 1 downto i*bus_byte_size) := word_in((i + 1)*bus_byte_size - 1 downto (i + 1)*bus_byte_size - nibble_size);
           ret_val((i + 1)*bus_byte_size - 1 downto (i + 1)*bus_byte_size - nibble_size) := word_in(nibble_size + i*bus_byte_size - 1 downto i*bus_byte_size);
        end loop;
        return ret_val;
    end reorder_nibbles;
end triple_23lc1024_tb_pkg;
