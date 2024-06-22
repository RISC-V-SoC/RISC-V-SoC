library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_csr_unprivileged_counter_timers is
    port (
        cycleCounter_value : in unsigned(63 downto 0);
        systemtimer_value : in unsigned(63 downto 0);
        instructionsRetired_value : in unsigned(63 downto 0);

        address : in natural range 0 to 31;
        read_high : in boolean;
        read_data : out riscv32_data_type;
        error : out boolean
    );
end entity;

architecture behaviourial of riscv32_csr_unprivileged_counter_timers is
    signal low_array : riscv32_data_array(2 downto 0);
    signal high_array : riscv32_data_array(2 downto 0);
begin
    low_array(0) <= std_logic_vector(cycleCounter_value(31 downto 0));
    low_array(1) <= std_logic_vector(systemtimer_value(31 downto 0));
    low_array(2) <= std_logic_vector(instructionsRetired_value(31 downto 0));

    high_array(0) <= std_logic_vector(cycleCounter_value(63 downto 32));
    high_array(1) <= std_logic_vector(systemtimer_value(63 downto 32));
    high_array(2) <= std_logic_vector(instructionsRetired_value(63 downto 32));

    process(read_high, address, low_array, high_array)
    begin
        error <= address > low_array'high;
        if address <= low_array'high then
            if read_high then
                read_data <= high_array(address);
            else
                read_data <= low_array(address);
            end if;
        else
            read_data <= (others => '-');
        end if;
    end process;
end architecture;
