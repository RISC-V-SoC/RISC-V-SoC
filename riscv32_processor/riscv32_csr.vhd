library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_csr is
    port (
        csr_in : in riscv32_to_csr_type;
        read_data : out riscv32_data_type;
        error : out boolean
    );
end entity;

architecture behaviourial of riscv32_csr is
begin
    error <= csr_in.do_read or csr_in.do_write;
end architecture;
