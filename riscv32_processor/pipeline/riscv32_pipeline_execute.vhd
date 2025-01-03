library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;
use work.riscv32_pkg.all;

entity riscv32_pipeline_execute is
    port (
        clk : in std_logic;
        rst : in boolean;

        stall_out : out boolean;

        -- From decode stage: control signals
        executeControlWord : in riscv32_ExecuteControlWord_type;

        -- From decode stage: data
        rs1Data : in riscv32_data_type;
        rs2Data : in riscv32_data_type;
        immidiate : in riscv32_data_type;
        programCounter : in riscv32_address_type;

        -- To Memory stage: data
        execResult : out riscv32_data_type;

        -- To instruction fetch: branch
        overrideProgramCounter : out boolean;
        newProgramCounter : out riscv32_address_type
    );
end entity;

architecture behaviourial of riscv32_pipeline_execute is
    signal aluResultImmidiate : riscv32_data_type;
    signal aluResultRtype : riscv32_data_type;
    signal bitManip_result : riscv32_data_type;
    signal mul_result : riscv32_data_type;
    signal div_result : riscv32_data_type;

    signal muldiv_result : riscv32_data_type;

    signal mul_stall : boolean;
    signal div_stall : boolean;
begin
    stall_out <= mul_stall or div_stall;

    determineExecResult : process(executeControlWord, aluResultRtype, aluResultImmidiate, programCounter, immidiate, muldiv_result)
    begin
        case executeControlWord.exec_directive is
            when riscv32_exec_alu_rtype =>
                execResult <= aluResultRtype;
            when riscv32_exec_alu_imm =>
                execResult <= aluResultImmidiate;
            when riscv32_exec_calcReturn =>
                execResult <= std_logic_vector(unsigned(programCounter) + 4);
            when riscv32_exec_lui =>
                execResult <= immidiate;
            when riscv32_exec_auipc =>
                execResult <= std_logic_vector(signed(immidiate) + signed(programCounter));
            when riscv32_exec_muldiv =>
                execResult <= muldiv_result;
        end case;
    end process;

    determineBranchTarget : process(programCounter, immidiate, rs1Data, executeControlWord)
    begin
        if executeControlWord.branch_cmd = cmd_branch_jalr then
            newProgramCounter <= std_logic_vector(signed(rs1Data) + signed(immidiate));
        else
            newProgramCounter <= std_logic_vector(signed(programCounter) + signed(immidiate));
        end if;
    end process;

    determineOverridePC : process(executeControlWord, rs1Data, rs2Data)
    begin
        overrideProgramCounter <= false;
        if executeControlWord.is_branch_op then
            case executeControlWord.branch_cmd is
                when cmd_branch_eq =>
                    overrideProgramCounter <= rs1Data = rs2Data;
                when cmd_branch_ne =>
                    overrideProgramCounter <= rs1Data /= rs2Data;
                when cmd_branch_lt =>
                    overrideProgramCounter <= signed(rs1Data) < signed(rs2Data);
                when cmd_branch_ltu =>
                    overrideProgramCounter <= unsigned(rs1Data) < unsigned(rs2Data);
                when cmd_branch_ge =>
                    overrideProgramCounter <= signed(rs1Data) >= signed(rs2Data);
                when cmd_branch_geu =>
                    overrideProgramCounter <= unsigned(rs1Data) >= unsigned(rs2Data);
                when cmd_branch_jalr =>
                    overrideProgramCounter <= true;
            end case;
        end if;
    end process;

    determineMuldivResult : process(mul_result, div_result, executeControlWord.muldiv_is_mul)
    begin
        if executeControlWord.muldiv_is_mul then
            muldiv_result <= mul_result;
        else
            muldiv_result <= div_result;
        end if;
    end process;

    alu_immidiate : entity work.riscv32_alu
    port map (
        inputA => rs1Data,
        inputB => immidiate,
        shamt => to_integer(unsigned(immidiate(4 downto 0))),
        cmd => executeControlWord.alu_cmd,
        output => aluResultImmidiate
    );

    alu_rtype : entity work.riscv32_alu
    port map (
        inputA => rs1Data,
        inputB => rs2Data,
        shamt => to_integer(unsigned(rs2Data(4 downto 0))),
        cmd => executeControlWord.alu_cmd,
        output => aluResultRtype
    );

    multiplier : entity work.riscv32_multiplier
    port map (
        clk => clk,
        rst => rst,

        inputA => rs1Data,
        inputB => rs2Data,
        outputWordHigh => executeControlWord.muldiv_alt_output,
        inputASigned => executeControlWord.rs1_signed,
        inputBSigned => executeControlWord.rs2_signed,

        do_operation => executeControlWord.exec_directive = riscv32_exec_muldiv and executeControlWord.muldiv_is_mul,
        stall => mul_stall,

        output => mul_result
    );

    divider : entity work.riscv32_nonrestoring_divider
    port map (
        clk => clk,
        rst => rst,

        dividend => rs1Data,
        divisor => rs2Data,
        is_signed => executeControlWord.rs1_signed,
        output_rem => executeControlWord.muldiv_alt_output,

        do_operation => executeControlWord.exec_directive = riscv32_exec_muldiv and not executeControlWord.muldiv_is_mul,
        stall => div_stall,

        output => div_result
    );
end architecture;
