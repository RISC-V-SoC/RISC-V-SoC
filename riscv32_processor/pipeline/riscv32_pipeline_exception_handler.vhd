library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_pipeline_exception_handler is
    port (
        clk : in std_logic;
        exception_data_in : in riscv32_exception_data_type;
        
        exception_trigger : out boolean;
        exception_code : out riscv32_exception_code_type;
        interrupted_pc : out riscv32_address_type;
        interrupt_is_async : out boolean
    );
end entity;

architecture behaviourial of riscv32_pipeline_exception_handler is
begin
    process(clk)
    begin
        if rising_edge(clk) then
            exception_trigger <= exception_data_in.carries_exception;
            exception_code <= exception_data_in.exception_code;
            interrupted_pc <= exception_data_in.interrupted_pc;
            interrupt_is_async <= exception_data_in.async_interrupt;
        end if;
    end process;
end architecture;
