library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;
use work.riscv32_pkg.all;

entity riscv32_pipeline_ifidreg is
    port (
        clk : in std_logic;
        rst : in boolean;
        stall : in boolean;
        force_bubble : in boolean;
        force_service_request : in boolean;
        
        enable_instruction_fetch : out boolean;

        program_counter : in riscv32_address_type;
        instruction_from_bus : in riscv32_instruction_type;
        has_fault_from_bus : in boolean;
        exception_code_from_bus : in riscv32_exception_code_type;

        exception_data_out : out riscv32_exception_data_type;
        instruction_out : out riscv32_instruction_type;
        program_counter_out : out riscv32_address_type;
        is_bubble : out boolean
    );
end entity;

architecture behaviourial of riscv32_pipeline_ifidreg is
    signal instruction_is_branch_or_jump: boolean := false;
    signal service_request_active : boolean := false;
begin
    handle_enable : process(force_bubble, instruction_is_branch_or_jump, service_request_active)
    begin
        if force_bubble or instruction_is_branch_or_jump or service_request_active then
            enable_instruction_fetch <= false;
        else
            enable_instruction_fetch <= true;
        end if;
    end process;

    process(clk)
        variable instruction_out_buf: riscv32_instruction_type := riscv32_instructionNop;
        variable program_counter_out_buf: riscv32_address_type := (others => '-');
        variable service_request_active_buf: boolean := false;
        variable is_bubble_buf: boolean := true;
        variable exception_data_out_buf: riscv32_exception_data_type := riscv32_exception_data_idle;
    begin
        if rising_edge(clk) then
            if rst then
                service_request_active_buf := false;
            elsif force_service_request then
                service_request_active_buf := true;
            end if;

            if rst then
                instruction_out_buf := riscv32_instructionNop;
                is_bubble_buf := true;
                program_counter_out_buf := (others => '-');
                exception_data_out_buf := riscv32_exception_data_idle;
            elsif stall then
                instruction_out_buf := instruction_out_buf;
                program_counter_out_buf := program_counter_out_buf;
                is_bubble_buf := is_bubble_buf;
                exception_data_out_buf := exception_data_out_buf;
            elsif has_fault_from_bus then
                exception_data_out_buf.exception_type := exception_sync;
                exception_data_out_buf.exception_code := exception_code_from_bus;
                exception_data_out_buf.interrupted_pc := program_counter;
                instruction_out_buf := riscv32_instructionNop;
                program_counter_out_buf := (others => '-');
                is_bubble_buf := true;
                service_request_active_buf := true;
            elsif service_request_active_buf then
                instruction_out_buf := riscv32_instructionNop;
                program_counter_out_buf := (others => '-');
                is_bubble_buf := true;
                exception_data_out_buf := exception_data_out_buf;
            elsif instruction_is_branch_or_jump or force_bubble then
                instruction_out_buf := riscv32_instructionNop;
                program_counter_out_buf := (others => '-');
                is_bubble_buf := true;
                exception_data_out_buf := exception_data_out_buf;
            else
                instruction_out_buf := instruction_from_bus;
                program_counter_out_buf := program_counter;
                is_bubble_buf := false;
                exception_data_out_buf.interrupted_pc := program_counter;
            end if;
        end if;
        instruction_is_branch_or_jump <= instruction_out_buf(6 downto 4) = "110";
        instruction_out <= instruction_out_buf;
        program_counter_out <= program_counter_out_buf;
        service_request_active <= service_request_active_buf;
        is_bubble <= is_bubble_buf;
        exception_data_out <= exception_data_out_buf;
    end process;
end architecture;
