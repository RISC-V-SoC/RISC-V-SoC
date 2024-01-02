library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;
use work.riscv32_pkg.all;

entity riscv32_control is
    port (
        instruction : in riscv32_instruction_type;

        instructionDecodeControlWord : out riscv32_InstructionDecodeControlWord_type;
        executeControlWord : out riscv32_ExecuteControlWord_type;
        memoryControlWord : out riscv32_MemoryControlWord_type;
        writeBackControlWord : out riscv32_WriteBackControlWord_type;

        illegal_instruction : out boolean

    );
end entity;

architecture behaviourial of riscv32_control is
begin
    decodeOpcode : process(instruction)
        variable instructionDecodeControlWord_buf : riscv32_InstructionDecodeControlWord_type;
        variable executeControlWord_buf : riscv32_ExecuteControlWord_type;
        variable memoryControlWord_buf : riscv32_MemoryControlWord_type;
        variable writeBackControlWord_buf : riscv32_WriteBackControlWord_type;

        variable opcode : riscv32_opcode_type;
        variable funct3 : riscv32_funct3_type;
        variable funct7 : riscv32_funct7_type;

        variable invalid_func : boolean := false;
        variable invalid_branch : boolean := false;
        variable invalid_store : boolean := false;
        variable invalid_load : boolean := false;
    begin
        instructionDecodeControlWord_buf := riscv32_instructionDecodeControlWordAllFalse;
        executeControlWord_buf := riscv32_executeControlWordAllFalse;
        memoryControlWord_buf := riscv32_memoryControlWordAllFalse;
        writeBackControlWord_buf := riscv32_writeBackControlWordAllFalse;

        opcode := to_integer(unsigned(instruction(6 downto 0)));
        funct3 := to_integer(unsigned(instruction(14 downto 12)));
        funct7 := to_integer(unsigned(instruction(31 downto 25)));
        illegal_instruction <= false;
        invalid_func := false;
        invalid_branch := false;
        invalid_store := false;
        invalid_load := false;

        case funct3 is
            when riscv32_funct3_add_sub =>
                if opcode = riscv32_opcode_opimm then
                    executeControlWord_buf.alu_cmd := cmd_alu_add;
                else
                    case funct7 is
                        when riscv32_funct7_add =>
                            executeControlWord_buf.alu_cmd := cmd_alu_add;
                        when riscv32_funct7_sub =>
                            executeControlWord_buf.alu_cmd := cmd_alu_sub;
                        when others =>
                            invalid_func := true;
                    end case;
                end if;
            when riscv32_funct3_slt =>
                executeControlWord_buf.alu_cmd := cmd_alu_slt;
            when riscv32_funct3_sltu =>
                executeControlWord_buf.alu_cmd := cmd_alu_sltu;
            when riscv32_funct3_and =>
                executeControlWord_buf.alu_cmd := cmd_alu_and;
            when riscv32_funct3_or =>
                executeControlWord_buf.alu_cmd := cmd_alu_or;
            when riscv32_funct3_xor =>
                executeControlWord_buf.alu_cmd := cmd_alu_xor;
            when riscv32_funct3_sll =>
                executeControlWord_buf.alu_cmd := cmd_alu_sll;
            when riscv32_funct3_srl_sra =>
                case funct7 is
                    when riscv32_funct7_srl =>
                        executeControlWord_buf.alu_cmd := cmd_alu_srl;
                    when riscv32_funct7_sra =>
                        executeControlWord_buf.alu_cmd := cmd_alu_sra;
                    when others =>
                        invalid_func := true;
                end case;
            when others =>
                invalid_func := true;
        end case;

        case funct3 is
            when riscv32_funct3_beq =>
                executeControlWord_buf.branch_cmd := cmd_branch_eq;
            when riscv32_funct3_bne =>
                executeControlWord_buf.branch_cmd := cmd_branch_ne;
            when riscv32_funct3_blt =>
                executeControlWord_buf.branch_cmd := cmd_branch_lt;
            when riscv32_funct3_bltu =>
                executeControlWord_buf.branch_cmd := cmd_branch_ltu;
            when riscv32_funct3_bge =>
                executeControlWord_buf.branch_cmd := cmd_branch_ge;
            when riscv32_funct3_bgeu =>
                executeControlWord_buf.branch_cmd := cmd_branch_geu;
            when others =>
                invalid_branch := true;
        end case;

        case funct3 is
            when riscv32_funct3_sw =>
                memoryControlWord_buf.loadStoreSize := ls_word;
            when riscv32_funct3_sh =>
                memoryControlWord_buf.loadStoreSize := ls_halfword;
            when riscv32_funct3_sb =>
                memoryControlWord_buf.loadStoreSize := ls_byte;
            when others =>
                invalid_store := true;
        end case;

        case funct3 is
            when riscv32_funct3_lw =>
                memoryControlWord_buf.loadStoreSize := ls_word;
                memoryControlWord_buf.memReadSignExtend := false;
            when riscv32_funct3_lh =>
                memoryControlWord_buf.loadStoreSize := ls_halfword;
                memoryControlWord_buf.memReadSignExtend := true;
            when riscv32_funct3_lhu =>
                memoryControlWord_buf.loadStoreSize := ls_halfword;
                memoryControlWord_buf.memReadSignExtend := false;
            when riscv32_funct3_lb =>
                memoryControlWord_buf.loadStoreSize := ls_byte;
                memoryControlWord_buf.memReadSignExtend := true;
            when riscv32_funct3_lbu =>
                memoryControlWord_buf.loadStoreSize := ls_byte;
                memoryControlWord_buf.memReadSignExtend := false;
            when others =>
                invalid_load := true;
        end case;

        case opcode is
            when riscv32_opcode_jalr =>
                executeControlWord_buf.exec_directive := riscv32_exec_calcReturn;
                executeControlWord_buf.is_branch_op := true;
                executeControlWord_buf.branch_cmd := cmd_branch_jalr;
                writeBackControlWord_buf.regWrite := true;
                writeBackControlWord_buf.MemtoReg := false;
            when riscv32_opcode_jal =>
                instructionDecodeControlWord_buf.jump := true;
                executeControlWord_buf.exec_directive := riscv32_exec_calcReturn;
                writeBackControlWord_buf.regWrite := true;
                writeBackControlWord_buf.MemtoReg := false;
            when riscv32_opcode_opimm =>
                instructionDecodeControlWord_buf.immidiate_type := riscv32_i_immidiate;
                executeControlWord_buf.exec_directive := riscv32_exec_alu_imm;
                writeBackControlWord_buf.regWrite := true;
                writeBackControlWord_buf.MemtoReg := false;
                illegal_instruction <= invalid_func;
            when riscv32_opcode_op =>
                executeControlWord_buf.exec_directive := riscv32_exec_alu_rtype;
                illegal_instruction <= invalid_func;
                writeBackControlWord_buf.regWrite := true;
                writeBackControlWord_buf.MemtoReg := false;
            when riscv32_opcode_lui =>
                instructionDecodeControlWord_buf.immidiate_type := riscv32_u_immidiate;
                executeControlWord_buf.exec_directive := riscv32_exec_lui;
                writeBackControlWord_buf.regWrite := true;
                writeBackControlWord_buf.MemtoReg := false;
            when riscv32_opcode_auipc =>
                instructionDecodeControlWord_buf.immidiate_type := riscv32_u_immidiate;
                executeControlWord_buf.exec_directive := riscv32_exec_auipc;
                writeBackControlWord_buf.regWrite := true;
                writeBackControlWord_buf.MemtoReg := false;
            when riscv32_opcode_branch =>
                instructionDecodeControlWord_buf.immidiate_type := riscv32_b_immidiate;
                executeControlWord_buf.is_branch_op := true;
                illegal_instruction <= invalid_branch;
                writeBackControlWord_buf.regWrite := false;
                writeBackControlWord_buf.MemtoReg := false;
            when riscv32_opcode_load =>
                instructionDecodeControlWord_buf.immidiate_type := riscv32_i_immidiate;
                executeControlWord_buf.exec_directive := riscv32_exec_alu_imm;
                executeControlWord_buf.alu_cmd := cmd_alu_add;
                memoryControlWord_buf.MemOp := true;
                memoryControlWord_buf.MemOpIsWrite := false;
                writeBackControlWord_buf.regWrite := true;
                writeBackControlWord_buf.MemtoReg := true;
                illegal_instruction <= invalid_load;
            when riscv32_opcode_store =>
                instructionDecodeControlWord_buf.immidiate_type := riscv32_s_immidiate;
                executeControlWord_buf.exec_directive := riscv32_exec_alu_imm;
                executeControlWord_buf.alu_cmd := cmd_alu_add;
                memoryControlWord_buf.MemOp := true;
                memoryControlWord_buf.MemOpIsWrite := true;
                writeBackControlWord_buf.regWrite := false;
                writeBackControlWord_buf.MemtoReg := false;
                illegal_instruction <= invalid_store;
            when others =>
                illegal_instruction <= true;
        end case;

        instructionDecodeControlWord <= instructionDecodeControlWord_buf;
        executeControlWord <= executeControlWord_buf;
        memoryControlWord <= memoryControlWord_buf;
        writeBackControlWord <= writeBackControlWord_buf;

    end process;


end behaviourial;
