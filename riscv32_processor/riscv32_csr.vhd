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

        address_to_user_readonly : out std_logic_vector(7 downto 0);
        read_data_from_user_readonly : in riscv32_data_type;
        error_from_user_readonly : in boolean
    );
end entity;

architecture behaviourial of riscv32_csr is
    constant CSR_READ_ONLY_ACCESS_MODE : std_logic_vector(1 downto 0) := "11";

    constant CSR_PRIVILEGE_LEVEL_USER : std_logic_vector(1 downto 0) := "00";
    constant CSR_PRIVILEGE_LEVEL_SUPERVISOR : std_logic_vector(1 downto 0) := "01";
    constant CSR_PRIVILEGE_LEVEL_HYPERVISOR : std_logic_vector(1 downto 0) := "10";
    constant CSR_PRIVILEGE_LEVEL_MACHINE : std_logic_vector(1 downto 0) := "11";

    alias access_mode : std_logic_vector(1 downto 0) is csr_in.address(11 downto 10);
    alias privilege_level : std_logic_vector(1 downto 0) is csr_in.address(9 downto 8);
    alias subaddress : std_logic_vector(7 downto 0) is csr_in.address(7 downto 0);

    signal address_is_read_only : boolean;
    signal read_only_error : boolean;
    signal out_of_range_error : boolean;
begin
    address_is_read_only <= access_mode = CSR_READ_ONLY_ACCESS_MODE;
    read_only_error <= csr_in.do_write and address_is_read_only;
    out_of_range_error <= csr_in.address(11 downto 10) /= "11";

    address_to_user_readonly <= subaddress;
    read_data <= read_data_from_user_readonly;
    error <= error_from_user_readonly or read_only_error or out_of_range_error;

end architecture;
