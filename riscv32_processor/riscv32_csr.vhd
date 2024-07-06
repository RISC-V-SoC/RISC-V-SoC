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
        error_from_user_readonly : in boolean;

        address_to_machine_readonly : out std_logic_vector(7 downto 0);
        read_data_from_machine_readonly : in riscv32_data_type;
        error_from_machine_readonly : in boolean
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
    signal privilege_level_error : boolean;
    signal error_input : boolean;
begin
    address_is_read_only <= access_mode = CSR_READ_ONLY_ACCESS_MODE;
    read_only_error <= csr_in.do_write and address_is_read_only;
    out_of_range_error <= access_mode /= CSR_READ_ONLY_ACCESS_MODE;
    privilege_level_error <= privilege_level /= CSR_PRIVILEGE_LEVEL_USER and privilege_level /= CSR_PRIVILEGE_LEVEL_MACHINE;

    error <= read_only_error or out_of_range_error or privilege_level_error or error_input;

    address_to_machine_readonly <= subaddress;
    address_to_user_readonly <= subaddress;

    reader : process(privilege_level, read_data_from_user_readonly, read_data_from_machine_readonly)
    begin
        case privilege_level is
            when CSR_PRIVILEGE_LEVEL_USER =>
                read_data <= read_data_from_user_readonly;
            when CSR_PRIVILEGE_LEVEL_MACHINE =>
                read_data <= read_data_from_machine_readonly;
            when others =>
                read_data <= (others => '-');
        end case;
    end process;

    input_error_handler : process(privilege_level, error_from_user_readonly, error_from_machine_readonly)
    begin
        case privilege_level is
            when CSR_PRIVILEGE_LEVEL_USER =>
                error_input <= error_from_user_readonly;
            when CSR_PRIVILEGE_LEVEL_MACHINE =>
                error_input <= error_from_machine_readonly;
            when others =>
                error_input <= false;
        end case;
    end process;

end architecture;
