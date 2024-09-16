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

    signal exception_trigger : boolean;
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
                exception_data_in.carries_exception <= true;
                exception_data_in.exception_code <= riscv32_exception_code_illegal_instruction;
                exception_data_in.async_interrupt <= false;
                exception_data_in.interrupted_pc <= x"00000000";
                wait until falling_edge(clk);
                check_true(exception_trigger);
                check_false(interrupt_is_async);
                check_equal(exception_code, exception_data_in.exception_code);
                check_equal(interrupted_pc, exception_data_in.interrupted_pc);
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
        exception_trigger => exception_trigger,
        exception_code => exception_code,
        interrupted_pc => interrupted_pc,
        interrupt_is_async => interrupt_is_async
    );
end architecture;
