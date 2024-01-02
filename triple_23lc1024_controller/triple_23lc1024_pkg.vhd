library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;

package triple_23lc1024_pkg is

    type cs_request_type is (request_none, request_zero, request_one, request_two);

    pure function is_address_legal_for_burst (
        address : bus_address_type
    ) return boolean;

    pure function encode_cs_request_type (
        address : bus_address_type
    ) return cs_request_type;

end triple_23lc1024_pkg;

package body triple_23lc1024_pkg is

    pure function is_address_legal_for_burst (
        address : bus_address_type
    ) return boolean is
        constant addr_num : natural := to_integer(unsigned(address));
        variable new_addr : natural := addr_num + bus_bytes_per_word;
        constant mask : natural := 16#20000#;
    begin
        return (addr_num mod mask) < (new_addr mod mask);
    end is_address_legal_for_burst;

    pure function encode_cs_request_type (
        address : bus_address_type
    ) return cs_request_type is
        variable val : std_logic_vector(1 downto 0) := address(18 downto 17);
        variable ret : cs_request_type := request_none;
    begin
        case val is
            when "00" =>
                ret := request_zero;
            when "01" =>
                ret := request_one;
            when "10" =>
                ret := request_two;
            when others =>
                ret := request_none;
        end case;
        return ret;
    end encode_cs_request_type;


end triple_23lc1024_pkg;
