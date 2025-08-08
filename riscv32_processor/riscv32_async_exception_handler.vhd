library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;
use work.riscv32_pkg.all;

entity riscv32_async_exception_handler is
    port (
        clk : in std_logic;

        async_exception_pending : out boolean;
        async_exception_code : out riscv32_exception_code_type;

        machine_interrupts_enabled : in boolean;

        machine_level_external_interrupt_pending : in boolean;
        machine_level_external_interrupt_enabled : in boolean;

        machine_level_timer_interrupt_pending : in boolean;
        machine_level_timer_interrupt_enabled : in boolean;

        machine_level_software_interrupt_pending : in boolean;
        machine_level_software_interrupt_enabled : in boolean
    );
end entity;

architecture behaviourial of riscv32_async_exception_handler is
begin
    process(clk, machine_interrupts_enabled)
    begin
        if rising_edge(clk) then
            async_exception_pending <= false;

            if machine_level_timer_interrupt_enabled and machine_level_timer_interrupt_pending then
                async_exception_pending <= true;
                async_exception_code <= riscv32_exception_code_machine_timer_interrupt;
            end if;

            if machine_level_software_interrupt_enabled and machine_level_software_interrupt_pending then
                async_exception_pending <= true;
                async_exception_code <= riscv32_exception_code_machine_software_interrupt;
            end if;

            if machine_level_external_interrupt_enabled and machine_level_external_interrupt_pending then
                async_exception_pending <= true;
                async_exception_code <= riscv32_exception_code_machine_external_interrupt;
            end if;
        end if;

        if not machine_interrupts_enabled then
            async_exception_pending <= false;
        end if;
    end process;
end behaviourial;
