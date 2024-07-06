library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_csr_machine_readonly is
    port (
        address : in std_logic_vector(7 downto 0);
        read_data : out riscv32_data_type;
        error : out boolean
    );
end entity;

architecture behaviourial of riscv32_csr_machine_readonly is
    constant mvendorid : riscv32_data_type := X"00000000";
    constant marchid : riscv32_data_type := X"00000000";
    constant mimpid : riscv32_data_type := X"00000000";
    constant mhartid : riscv32_data_type := X"00000000";
    constant mconfigptr : riscv32_data_type := X"00000000";

    constant ro_array : riscv32_data_array(4 downto 0) := (
        mvendorid,
        marchid,
        mimpid,
        mhartid,
        mconfigptr
    );

    signal act_address : unsigned(3 downto 0);
begin
    act_address <= unsigned(address(3 downto 0));

    process(address, act_address)
    begin
        error <= act_address > ro_array'high or address(7 downto 4) /= "0001";
        if act_address <= ro_array'high then
            read_data <= ro_array(to_integer(act_address));
        else
            read_data <= (others => '-');
        end if;
    end process;
end architecture;
