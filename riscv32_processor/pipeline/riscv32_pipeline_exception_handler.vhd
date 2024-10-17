library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_pipeline_exception_handler is
    port (
        clk : in std_logic;
        exception_data_in : in riscv32_exception_data_type;

        exception_vector_base_address : in riscv32_address_type;
        exception_return_address : in riscv32_address_type;

        address_to_instruction_fetch : out riscv32_address_type;

        exception_trigger : out boolean;
        exception_resolved : out boolean;
        exception_code : out riscv32_exception_code_type;
        interrupted_pc : out riscv32_address_type;
        interrupt_is_async : out boolean
    );
end entity;

architecture behaviourial of riscv32_pipeline_exception_handler is
begin
    process(clk)
        variable async_offset : unsigned(exception_vector_base_address'range) := (others => '0');
    begin
        if rising_edge(clk) then
            async_offset := to_unsigned(exception_data_in.exception_code * 4, async_offset'length);

            if exception_data_in.exception_type = exception_return then
                exception_trigger <= false;
                exception_resolved <= true;
            elsif exception_data_in.exception_type = exception_none then
                exception_trigger <= false;
                exception_resolved <= false;
            else
                exception_trigger <= true;
                exception_resolved <= false;
            end if;

            exception_code <= exception_data_in.exception_code;
            interrupted_pc <= exception_data_in.interrupted_pc;
            interrupt_is_async <= exception_data_in.exception_type = exception_async;

            if exception_data_in.exception_type = exception_sync then
                address_to_instruction_fetch <= exception_vector_base_address;
            elsif exception_data_in.exception_type = exception_return then
                address_to_instruction_fetch <= exception_return_address;
            elsif exception_data_in.exception_type = exception_async then
                address_to_instruction_fetch <= std_logic_vector(unsigned(exception_vector_base_address) + async_offset);
            end if;
        end if;
    end process;
end architecture;
