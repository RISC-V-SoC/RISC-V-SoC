library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_csr is
    port (
        csr_in : in riscv32_to_csr_type;
        cycleCounter_value : in unsigned(63 downto 0);
        systemtimer_value : in unsigned(63 downto 0);
        instructionsRetired_value : in unsigned(63 downto 0);
        read_data : out riscv32_data_type;
        error : out boolean
    );
end entity;

architecture behaviourial of riscv32_csr is
begin

    process(csr_in, systemtimer_value, cycleCounter_value, instructionsRetired_value)
    begin
        error <= false;
        read_data <= (others => 'X');
        if csr_in.do_write then
            error <= true;
        elsif csr_in.do_read then
            if csr_in.address = X"C00" then
                read_data <= std_logic_vector(cycleCounter_value(31 downto 0));
            elsif csr_in.address = X"C01" then
                read_data <= std_logic_vector(systemtimer_value(31 downto 0));
            elsif csr_in.address = X"C02" then
                read_data <= std_logic_vector(instructionsRetired_value(31 downto 0));
            elsif csr_in.address = X"C80" then
                read_data <= std_logic_vector(cycleCounter_value(63 downto 32));
            elsif csr_in.address = X"C81" then
                read_data <= std_logic_vector(systemtimer_value(63 downto 32));
            elsif csr_in.address = X"C82" then
                read_data <= std_logic_vector(instructionsRetired_value(63 downto 32));
            else
                error <= true;
            end if;
        else
            error <= false;
        end if;
    end process;
end architecture;
