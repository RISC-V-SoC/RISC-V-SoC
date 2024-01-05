library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg;

entity riscv32_coprocessor_zero is
    generic (
        clk_period : time
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        address_from_controller : in natural range 0 to 31;

        write_from_controller : in boolean;

        data_from_controller : in riscv32_pkg.riscv32_data_type;

        data_to_controller : out riscv32_pkg.riscv32_data_type;

        cpu_reset : out boolean;
        cpu_stall : out boolean
    );
end entity;

architecture behaviourial of riscv32_coprocessor_zero is
    constant clk_frequency : natural := (1 sec)/clk_period;
    signal regFile : riscv32_pkg.riscv32_data_array(0 to 1);
begin

    cpu_reset <= regFile(0)(0) = '1';
    cpu_stall <= regFile(0)(1) = '1';

    regFile(1) <= std_logic_vector(to_unsigned(clk_frequency, regFile(1)'length));

    controller_reader : process(address_from_controller, regFile)
    begin
        if address_from_controller > regFile'high then
            data_to_controller <= (others => '0');
        else
            data_to_controller <= regFile(address_from_controller);
        end if;
    end process;

    regZeroControl: process(clk)
        variable regZero_buf : riscv32_pkg.riscv32_data_type := (0 => '1', others => '0');
    begin
        if rising_edge(clk) then
            if rst = '1' then
                regZero_buf := (0 => '1', others => '0');
            else
                if  write_from_controller and address_from_controller = 0 then
                    regZero_buf := data_from_controller;
                end if;
            end if;
        end if;
        regZero_buf(31 downto 2) := (others => '0');
        regFile(0) <= regZero_buf;
    end process;


end architecture;
