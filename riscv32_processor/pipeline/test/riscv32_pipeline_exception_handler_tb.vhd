library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.riscv32_pkg.all;

entity riscv32_pipeline_exception_handler_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of riscv32_pipeline_exception_handler_tb is
    constant clk_period : time := 20 ns;
    signal clk : std_logic := '0';
    signal exception_data_in : riscv32_exception_data_type := riscv32_exception_data_idle;

    signal exception_base_address : riscv32_address_type := X"20000000";
    signal exception_return_address : riscv32_address_type := X"40000000";
    signal address_to_instruction_fetch : riscv32_address_type;

    signal exception_trigger : boolean;
    signal exception_resolved : boolean;
    signal exception_code : riscv32_exception_code_type;
    signal interrupted_pc : riscv32_address_type;
    signal interrupt_is_async : boolean;
begin
    clk <= not clk after (clk_period/2);
    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Forwards input") then
                exception_data_in.exception_type <= exception_sync;
                exception_data_in.exception_code <= riscv32_exception_code_illegal_instruction;
                exception_data_in.interrupted_pc <= x"00000000";
                wait until falling_edge(clk);
                check_true(exception_trigger);
                check_false(interrupt_is_async);
                check_equal(exception_code, exception_data_in.exception_code);
                check_equal(interrupted_pc, exception_data_in.interrupted_pc);
            elsif run("Async exception sets interrupt_is_async") then
                exception_data_in.exception_type <= exception_async;
                exception_data_in.exception_code <= riscv32_exception_code_illegal_instruction;
                exception_data_in.interrupted_pc <= x"00000004";
                wait until falling_edge(clk);
                check_true(exception_trigger);
                check_true(interrupt_is_async);
                check_equal(exception_code, exception_data_in.exception_code);
                check_equal(interrupted_pc, exception_data_in.interrupted_pc);
            elsif run("On sync exception, address_to_instruction_fetch is set to exception_base_address") then
                exception_data_in.exception_type <= exception_sync;
                exception_data_in.exception_code <= riscv32_exception_code_illegal_instruction;
                exception_data_in.interrupted_pc <= x"00000000";
                wait until falling_edge(clk);
                check_equal(address_to_instruction_fetch, exception_base_address);
            elsif run("On exception_return, address_to_instruction_fetch is set to exception_return_address") then
                exception_data_in.exception_type <= exception_return;
                exception_data_in.exception_code <= riscv32_exception_code_illegal_instruction;
                exception_data_in.interrupted_pc <= x"00000000";
                wait until falling_edge(clk);
                check_equal(address_to_instruction_fetch, exception_return_address);
            elsif run("On async except and exception code 1, address_to_instruction_fetch is set to exception_base_address + 4") then
                exception_data_in.exception_type <= exception_async;
                exception_data_in.exception_code <= 1;
                exception_data_in.interrupted_pc <= x"00000000";
                wait until falling_edge(clk);
                check_equal(address_to_instruction_fetch, std_logic_vector(unsigned(exception_base_address) + 4));
            elsif run("On async except and exception code 20, address_to_instruction_fetch is set to exception_base_address + 80") then
                exception_data_in.exception_type <= exception_async;
                exception_data_in.exception_code <= 20;
                exception_data_in.interrupted_pc <= x"00000000";
                wait until falling_edge(clk);
                check_equal(address_to_instruction_fetch, std_logic_vector(unsigned(exception_base_address) + 80));
            elsif run("On exception return, exception resolved is true, exception trigger is false") then
                exception_data_in.exception_type <= exception_return;
                exception_data_in.exception_code <= riscv32_exception_code_illegal_instruction;
                exception_data_in.interrupted_pc <= x"00000000";
                wait until falling_edge(clk);
                check_true(exception_resolved);
                check_false(exception_trigger);
            elsif run("When no exception, neither exception resolved, nor exception triggered is true") then
                exception_data_in.exception_type <= exception_none;
                exception_data_in.exception_code <= riscv32_exception_code_illegal_instruction;
                exception_data_in.interrupted_pc <= x"00000000";
                wait until falling_edge(clk);
                check_false(exception_resolved);
                check_false(exception_trigger);
            end if;
        end loop;
        wait until rising_edge(clk);
        wait until falling_edge(clk);
        test_runner_cleanup(runner);
        wait;
    end process;

    exception_handler : entity src.riscv32_pipeline_exception_handler
    port map (
        clk => clk,
        exception_data_in => exception_data_in,
        exception_vector_base_address => exception_base_address,
        exception_return_address => exception_return_address,
        address_to_instruction_fetch => address_to_instruction_fetch,
        exception_trigger => exception_trigger,
        exception_resolved => exception_resolved,
        exception_code => exception_code,
        interrupted_pc => interrupted_pc,
        interrupt_is_async => interrupt_is_async
    );
end architecture;
