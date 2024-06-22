library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_csr is
    port (
        csr_in : in riscv32_to_csr_type;
        read_data : out riscv32_data_type;
        error : out boolean;

        address_to_unprivileged_counter_timers : out natural range 0 to 31;
        read_high_to_unprivileged_counter_timers : out boolean;
        read_data_from_unprivileged_counter_timers : in riscv32_data_type;
        error_from_unprivileged_counter_timers : in boolean
    );
end entity;

architecture behaviourial of riscv32_csr is
    signal address_is_read_only : boolean;
    signal read_only_error : boolean;
    signal out_of_range_error : boolean;
begin
    address_is_read_only <= csr_in.address(11 downto 10) = "11";
    read_only_error <= csr_in.do_write and address_is_read_only;
    out_of_range_error <= csr_in.address(11 downto 10) /= "11" or csr_in.address(6 downto 5) /= "00";

    address_to_unprivileged_counter_timers <= to_integer(unsigned(csr_in.address(4 downto 0)));
    read_high_to_unprivileged_counter_timers <= csr_in.address(7) = '1';
    read_data <= read_data_from_unprivileged_counter_timers;
    error <= error_from_unprivileged_counter_timers or read_only_error or out_of_range_error;

end architecture;
