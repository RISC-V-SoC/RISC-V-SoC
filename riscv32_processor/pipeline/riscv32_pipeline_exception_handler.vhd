library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_pipeline_exception_handler is
    generic (
        propagation_delay : natural range 1 to natural'high
    );
    port (
        clk : in std_logic;
        rst : in boolean;
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
    type riscv32_exception_data_array is array (natural range <>) of riscv32_exception_data_type;
    constant array_size : natural := propagation_delay - 1;
    signal exception_array : riscv32_exception_data_array(0 to array_size) := (others => (riscv32_exception_data_idle));
    signal actual_exception_data : riscv32_exception_data_type;
begin

    actual_exception_data <= exception_array(array_size);

    propagate : process(clk)
    begin
        if rising_edge(clk) then
            if rst then
                for i in 0 to array_size loop
                    exception_array(i) <= riscv32_exception_data_idle;
                end loop;
            else
                exception_array(0) <= exception_data_in;
                for i in 1 to array_size loop
                    exception_array(i) <= exception_array(i - 1);
                end loop;
            end if;
        end if;
    end process;

    process(clk)
        variable async_offset : unsigned(exception_vector_base_address'range) := (others => '0');
    begin
        if rising_edge(clk) then
            async_offset := to_unsigned(actual_exception_data.exception_code * 4, async_offset'length);

            if actual_exception_data.exception_type = exception_return then
                exception_trigger <= false;
                exception_resolved <= true;
            elsif actual_exception_data.exception_type = exception_none then
                exception_trigger <= false;
                exception_resolved <= false;
            else
                exception_trigger <= true;
                exception_resolved <= false;
            end if;

            exception_code <= actual_exception_data.exception_code;
            interrupted_pc <= actual_exception_data.interrupted_pc;
            interrupt_is_async <= actual_exception_data.exception_type = exception_async;

            if actual_exception_data.exception_type = exception_sync then
                address_to_instruction_fetch <= exception_vector_base_address;
            elsif actual_exception_data.exception_type = exception_return then
                address_to_instruction_fetch <= exception_return_address;
            elsif actual_exception_data.exception_type = exception_async then
                address_to_instruction_fetch <= std_logic_vector(unsigned(exception_vector_base_address) + async_offset);
            end if;
        end if;
    end process;
end architecture;
