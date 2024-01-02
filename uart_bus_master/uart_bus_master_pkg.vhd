library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package uart_bus_master_pkg is
    constant ERROR_NO_ERROR : std_logic_vector(7 downto 0) := X"00";
    constant ERROR_UNKOWN_COMMAND : std_logic_vector(7 downto 0) := X"01";
    constant ERROR_BUS : std_logic_vector(7 downto 0) := X"02";

    constant COMMAND_READ_WORD : std_logic_vector(7 downto 0) := X"01";
    constant COMMAND_WRITE_WORD : std_logic_vector(7 downto 0) := X"02";
    constant COMMAND_READ_WORD_SEQUENCE : std_logic_vector(7 downto 0) := X"03";
    constant COMMAND_WRITE_WORD_SEQUENCE : std_logic_vector(7 downto 0) := X"04";
end package;
