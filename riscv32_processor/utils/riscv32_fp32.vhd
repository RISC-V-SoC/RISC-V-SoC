library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;
use work.riscv32_fp32_pkg.all;

entity riscv32_fp32 is
    port (
        clk : in std_logic;
        rst : in boolean;

        low_prio_rounding_mode : in riscv32_f32_rounding_mode;
        high_prio_rounding_mode : in riscv32_f32_rounding_mode;

        inputA : in riscv32_data_type;
        inputB : in riscv32_data_type;
        inputC : in riscv32_data_type;

        do_operation : in boolean;
        operation : in riscv32_f32_cmd;
        stall : out boolean;

        output : out riscv32_data_type;
        err_flags : out riscv32_f32_exception_flags
    );
end entity;

architecture behaviourial of riscv32_fp32 is
    constant delay_cycles : natural := 5;

    type combinedInputType is record
        inputA : riscv32_data_type;
        inputB : riscv32_data_type;
        inputC : riscv32_data_type;
        operation : riscv32_f32_cmd;
    end record;

    constant combinedInputDefault : combinedInputType := (
        inputA => (others => '0'),
        inputB => (others => '0'),
        inputC => (others => '0'),
        operation => f32_cmd_mul
    );

    signal combinedInputCache : combinedInputType := combinedInputDefault;
    signal combinedInput : combinedInputType;

    signal stall_buf : boolean;

    procedure advance_state(
        variable buf : inout resultType_arr;
        variable count : inout natural;
        variable push_val : in resultType;
        variable out_var : out resultType;
        variable complete : out boolean) is
    begin
        buf := buf(buf'high - 1 downto 0) & push_val;
        out_var := buf(buf'high);
        if count = buf'high + 1 then
            complete := true;
            count := 0;
        else
            complete := false;
            count := count + 1;
        end if;
    end procedure;

begin
    combinedInput.inputA <= inputA;
    combinedInput.inputB <= inputB;
    combinedInput.inputC <= inputC;
    combinedInput.operation <= operation;

    stall_buf <= do_operation and combinedInputCache /= combinedInput;
    stall <= stall_buf;

    main_proc : process(clk, stall_buf)
        variable res : resultType;
        variable count : natural := 0;
        variable output_buffer : resultType_arr(delay_cycles - 1 downto 0) := (others => resultType_default);
        variable buf_out : resultType;
        variable complete : boolean;
    begin
        if rising_edge(clk) and stall_buf then
            case operation is
                when f32_cmd_utof => res := unsigned_to_float(inputA, high_prio_rounding_mode);
                when f32_cmd_itof => res := signed_to_float(inputA, high_prio_rounding_mode);
                when others => res := resultType_default;
            end case;
            advance_state(output_buffer, count, res, buf_out, complete);
            output <= buf_out.result;
            err_flags <= buf_out.err_flags;
            if complete then
                combinedInputCache <= combinedInput;
            end if;
        end if;
    end process;
end architecture;
