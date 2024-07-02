library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_csr_user_readonly is
    port (
        cycleCounter_value : in unsigned(63 downto 0);
        systemtimer_value : in unsigned(63 downto 0);
        instructionsRetired_value : in unsigned(63 downto 0);

        address : in std_logic_vector(7 downto 0);
        read_data : out riscv32_data_type;
        error : out boolean
    );
end entity;

architecture behaviourial of riscv32_csr_user_readonly is
    signal low_array : riscv32_data_array(2 downto 0);
    signal high_array : riscv32_data_array(2 downto 0);

    signal read_high : boolean;
    signal partial_address : natural range 0 to 31;
begin
    read_high <= address(7) = '1';
    partial_address <= to_integer(unsigned(address(4 downto 0)));

    low_array(0) <= std_logic_vector(cycleCounter_value(31 downto 0));
    low_array(1) <= std_logic_vector(systemtimer_value(31 downto 0));
    low_array(2) <= std_logic_vector(instructionsRetired_value(31 downto 0));

    high_array(0) <= std_logic_vector(cycleCounter_value(63 downto 32));
    high_array(1) <= std_logic_vector(systemtimer_value(63 downto 32));
    high_array(2) <= std_logic_vector(instructionsRetired_value(63 downto 32));

    process(read_high, address, low_array, high_array, partial_address)
    begin
        error <= partial_address > low_array'high or address(6 downto 5) /= "00";
        if partial_address <= low_array'high then
            if read_high then
                read_data <= high_array(partial_address);
            else
                read_data <= low_array(partial_address);
            end if;
        else
            read_data <= (others => '-');
        end if;
    end process;
end architecture;
