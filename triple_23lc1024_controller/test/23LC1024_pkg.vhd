library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

package M23LC1024_pkg is
    type OperationMode is (ByteMode, PageMode, SeqMode);
    type InoutMode is (SpiMode, SdiMode, SqiMode);

    constant read_reply_msg : msg_type_t := new_msg_type("read reply");

    constant read_operationMode_msg     : msg_type_t := new_msg_type("read operationMode");
    constant write_operationMode_msg    : msg_type_t := new_msg_type("write operationMode");

    constant read_inoutMode_msg : msg_type_t := new_msg_type("read inoutMode");
    constant write_inoutMode_msg : msg_type_t := new_msg_type("write inoutMode");

    constant read_fromAddress_msg : msg_type_t := new_msg_type("read from address");
    constant write_toAddress_msg : msg_type_t := new_msg_type("write to address");

    procedure read_operationMode(
              signal net : inout network_t;
              constant actor : in actor_t;
              variable data : out OperationMode);

    procedure write_operationMode(
              signal net : inout network_t;
              constant actor : in actor_t;
              constant data : in OperationMode);

    procedure read_inoutMode(
              signal net : inout network_t;
              constant actor : in actor_t;
              variable data : out InoutMode);

    procedure write_inoutMode(
              signal net : inout network_t;
              constant actor : in actor_t;
              constant data : in InoutMode);

    procedure read_from_address(
              signal net : inout network_t;
              constant actor : in actor_t;
              constant addr : in std_logic_vector(16 downto 0);
              variable data : out std_logic_vector(7 downto 0));

    procedure write_to_address(
              signal net : inout network_t;
              constant actor : in actor_t;
              constant addr : in std_logic_vector(16 downto 0);
              constant data : in std_logic_vector(7 downto 0));

    pure function decodeModeRegister(modeRegister : std_logic_vector(7 downto 0)) return OperationMode;
    pure function encodeModeRegister(curMode : OperationMode) return std_logic_vector;
    pure function decodeInoutMode(modeRegister : std_logic_vector(7 downto 0)) return inoutMode;
    pure function encodeInoutMode(curMode : inoutMode) return std_logic_vector;

end package;

package body M23LC1024_pkg is
    procedure read_operationMode(
              signal net : inout network_t;
              constant actor : in actor_t;
              variable data : out OperationMode) is
        variable msg : msg_t := new_msg(read_operationMode_msg);
        variable reply_msg : msg_t;
    begin
        request(net, actor, msg, reply_msg);
        data := decodeModeRegister(pop(reply_msg));
    end;

    procedure write_operationMode(
              signal net : inout network_t;
              constant actor : in actor_t;
              constant data : in OperationMode) is
        variable msg : msg_t := new_msg(write_operationMode_msg);
        variable positive_ack : boolean;
    begin
        push(msg, encodeModeRegister(data));
        request(net, actor, msg, positive_ack);
        check(positive_ack, "Write failed");
    end;

    procedure read_inoutMode(
              signal net : inout network_t;
              constant actor : in actor_t;
              variable data : out InoutMode) is
        variable msg : msg_t := new_msg(read_inoutMode_msg);
        variable reply_msg : msg_t;
    begin
        request(net, actor, msg, reply_msg);
        data := decodeInoutMode(pop(reply_msg));
    end;

    procedure write_inoutMode(
              signal net : inout network_t;
              constant actor : in actor_t;
              constant data : in InoutMode) is
        variable msg : msg_t := new_msg(write_inoutMode_msg);
        variable positive_ack : boolean;
    begin
        push(msg, encodeInoutMode(data));
        request(net, actor, msg, positive_ack);
        check(positive_ack, "Write failed");
    end;

    procedure read_from_address(
              signal net : inout network_t;
              constant actor : in actor_t;
              constant addr : in std_logic_vector(16 downto 0);
              variable data : out std_logic_vector(7 downto 0)) is
        variable msg : msg_t := new_msg(read_fromAddress_msg);
        variable reply_msg : msg_t;
    begin
        push(msg, addr);
        request(net, actor, msg, reply_msg);
        data := pop(reply_msg);
    end;

    procedure write_to_address(
              signal net : inout network_t;
              constant actor : in actor_t;
              constant addr : in std_logic_vector(16 downto 0);
              constant data : in std_logic_vector(7 downto 0)) is
        variable msg : msg_t := new_msg(write_toAddress_msg);
        variable positive_ack : boolean;
    begin
        push(msg, data);
        push(msg, addr);
        request(net, actor, msg, positive_ack);
        check(positive_ack, "write_to_address failed");
    end;


    pure function decodeModeRegister(modeRegister : std_logic_vector(7 downto 0)) return OperationMode is
        variable ret_val : OperationMode := ByteMode;
    begin
        assert (modeRegister(5 downto 0) = "000000") report "Last 6 bit of mode register write should be all zeros!" severity error;
        case modeRegister(7 downto 6) is
            when "00" =>
                ret_val := ByteMode;
            when "01" =>
                ret_val := SeqMode;
            when "10" =>
                ret_val := PageMode;
            when others =>
                assert false report "Illegal mode" severity error;
        end case;
        return ret_val;
    end function;

    pure function encodeModeRegister(curMode : OperationMode) return std_logic_vector is
        variable ret_val : std_logic_vector(7 downto 0) := (others => '0');
    begin
        case curMode is
            when ByteMode =>
                ret_val(7 downto 6) := "00";
            when SeqMode =>
                ret_val(7 downto 6) := "01";
            when PageMode =>
                ret_val(7 downto 6) := "10";
        end case;
        return ret_val;
    end function;

    pure function decodeInoutMode(modeRegister : std_logic_vector(7 downto 0)) return inoutMode is
        variable ret_val : inoutMode := SpiMode;
    begin
        assert (modeRegister(5 downto 0) = "000000") report "Last 6 bit of mode register write should be all zeros!" severity error;
        case modeRegister(7 downto 6) is
            when "00" =>
                ret_val := SpiMode;
            when "01" =>
                ret_val := SdiMode;
            when "10" =>
                ret_val := SqiMode;
            when others =>
                assert false report "Illegal mode" severity error;
        end case;
        return ret_val;
    end function;

    pure function encodeInoutMode(curMode : inoutMode) return std_logic_vector is
        variable ret_val : std_logic_vector(7 downto 0) := (others => '0');
    begin
        case curMode is
            when SpiMode =>
                ret_val(7 downto 6) := "00";
            when SdiMode =>
                ret_val(7 downto 6) := "01";
            when SqiMode =>
                ret_val(7 downto 6) := "10";
        end case;
        return ret_val;
    end function;

end package body M23LC1024_pkg;

