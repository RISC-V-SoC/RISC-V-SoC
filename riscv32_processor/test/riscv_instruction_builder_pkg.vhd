library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library src;
use src.riscv32_pkg.all;

package riscv32_instruction_builder_pkg is

    pure function construct_rtype_instruction (
        opcode : riscv32_opcode_type := riscv32_opcode_op;
        rs1 : riscv32_registerFileAddress_type := 0;
        rs2 : riscv32_registerFileAddress_type := 0;
        rd : riscv32_registerFileAddress_type := 0;
        funct3 : riscv32_funct3_type := 0;
        funct7 : riscv32_funct7_type := 0
    ) return riscv32_instruction_type;

    pure function construct_itype_instruction (
        opcode : riscv32_opcode_type := riscv32_opcode_op;
        rs1 : riscv32_registerFileAddress_type := 0;
        rd : riscv32_registerFileAddress_type := 0;
        funct3 : riscv32_funct3_type := 0;
        imm12 : std_logic_vector(11 downto 0) := (others => '0')
    ) return riscv32_instruction_type;

    pure function construct_stype_instruction (
        opcode : riscv32_opcode_type := riscv32_opcode_op;
        rs1 : riscv32_registerFileAddress_type := 0;
        rs2 : riscv32_registerFileAddress_type := 0;
        funct3 : riscv32_funct3_type := 0;
        imm5 : std_logic_vector(4 downto 0) := (others => '0');
        funct7 : riscv32_funct7_type := 0
    ) return riscv32_instruction_type;

    pure function construct_btype_instruction (
        opcode : riscv32_opcode_type := riscv32_opcode_op;
        rs1 : riscv32_registerFileAddress_type := 0;
        rs2 : riscv32_registerFileAddress_type := 0;
        funct3 : riscv32_funct3_type := 0;
        imm5 : std_logic_vector(4 downto 0) := (others => '0');
        imm7 : std_logic_vector(6 downto 0) := (others => '0')
    ) return riscv32_instruction_type;

    pure function construct_utype_instruction (
        opcode : riscv32_opcode_type := riscv32_opcode_op;
        rd : riscv32_registerFileAddress_type := 0;
        imm20 : std_logic_vector(19 downto 0) := (others => '0')
    ) return riscv32_instruction_type;

    pure function construct_system_instruction (
        opcode : riscv32_opcode_type := riscv32_opcode_op;
        funct3 : riscv32_funct3_type := 0;
        funct12 : riscv32_funct12_type := 0
    ) return riscv32_instruction_type;

end package;

package body riscv32_instruction_builder_pkg is

    pure function construct_rtype_instruction (
        opcode : riscv32_opcode_type := riscv32_opcode_op;
        rs1 : riscv32_registerFileAddress_type := 0;
        rs2 : riscv32_registerFileAddress_type := 0;
        rd : riscv32_registerFileAddress_type := 0;
        funct3 : riscv32_funct3_type := 0;
        funct7 : riscv32_funct7_type := 0
    ) return riscv32_instruction_type is
        variable instruction : riscv32_instruction_type;
    begin
        instruction(31 downto 25) := std_logic_vector(to_unsigned(funct7, 7));
        instruction(24 downto 20) := std_logic_vector(to_unsigned(rs2, 5));
        instruction(19 downto 15) := std_logic_vector(to_unsigned(rs1, 5));
        instruction(14 downto 12) := std_logic_vector(to_unsigned(funct3, 3));
        instruction(11 downto 7) := std_logic_vector(to_unsigned(rd, 5));
        instruction(6 downto 0) := std_logic_vector(to_unsigned(opcode, 7));
        return instruction;
    end function;

    pure function construct_itype_instruction (
        opcode : riscv32_opcode_type := riscv32_opcode_op;
        rs1 : riscv32_registerFileAddress_type := 0;
        rd : riscv32_registerFileAddress_type := 0;
        funct3 : riscv32_funct3_type := 0;
        imm12 : std_logic_vector(11 downto 0) := (others => '0')
    ) return riscv32_instruction_type is
        variable instruction : riscv32_instruction_type;
    begin
        instruction(31 downto 20) := imm12;
        instruction(19 downto 15) := std_logic_vector(to_unsigned(rs1, 5));
        instruction(14 downto 12) := std_logic_vector(to_unsigned(funct3, 3));
        instruction(11 downto 7) := std_logic_vector(to_unsigned(rd, 5));
        instruction(6 downto 0) := std_logic_vector(to_unsigned(opcode, 7));
        return instruction;
    end function;

    pure function construct_stype_instruction (
        opcode : riscv32_opcode_type := riscv32_opcode_op;
        rs1 : riscv32_registerFileAddress_type := 0;
        rs2 : riscv32_registerFileAddress_type := 0;
        funct3 : riscv32_funct3_type := 0;
        imm5 : std_logic_vector(4 downto 0) := (others => '0');
        funct7 : riscv32_funct7_type := 0
    ) return riscv32_instruction_type is
        variable instruction : riscv32_instruction_type;
    begin
        instruction(31 downto 25) := std_logic_vector(to_unsigned(funct7, 7));
        instruction(24 downto 20) := std_logic_vector(to_unsigned(rs2, 5));
        instruction(19 downto 15) := std_logic_vector(to_unsigned(rs1, 5));
        instruction(14 downto 12) := std_logic_vector(to_unsigned(funct3, 3));
        instruction(11 downto 7) := imm5;
        instruction(6 downto 0) := std_logic_vector(to_unsigned(opcode, 7));
        return instruction;
    end function;

    pure function construct_btype_instruction (
        opcode : riscv32_opcode_type := riscv32_opcode_op;
        rs1 : riscv32_registerFileAddress_type := 0;
        rs2 : riscv32_registerFileAddress_type := 0;
        funct3 : riscv32_funct3_type := 0;
        imm5 : std_logic_vector(4 downto 0) := (others => '0');
        imm7 : std_logic_vector(6 downto 0) := (others => '0')
    ) return riscv32_instruction_type is
        variable instruction : riscv32_instruction_type;
    begin
        instruction(31 downto 25) := imm7;
        instruction(24 downto 20) := std_logic_vector(to_unsigned(rs2, 5));
        instruction(19 downto 15) := std_logic_vector(to_unsigned(rs1, 5));
        instruction(14 downto 12) := std_logic_vector(to_unsigned(funct3, 3));
        instruction(11 downto 7) := imm5;
        instruction(6 downto 0) := std_logic_vector(to_unsigned(opcode, 7));
        return instruction;
    end function;

    pure function construct_utype_instruction (
        opcode : riscv32_opcode_type := riscv32_opcode_op;
        rd : riscv32_registerFileAddress_type := 0;
        imm20 : std_logic_vector(19 downto 0) := (others => '0')
    ) return riscv32_instruction_type is
        variable instruction : riscv32_instruction_type;
    begin
        instruction(31 downto 12) := imm20;
        instruction(11 downto 7) := std_logic_vector(to_unsigned(rd, 5));
        instruction(6 downto 0) := std_logic_vector(to_unsigned(opcode, 7));
        return instruction;
    end function;

    pure function construct_system_instruction (
        opcode : riscv32_opcode_type := riscv32_opcode_op;
        funct3 : riscv32_funct3_type := 0;
        funct12 : riscv32_funct12_type := 0
    ) return riscv32_instruction_type is
        variable instruction : riscv32_instruction_type;
    begin
        instruction(31 downto 20) := std_logic_vector(to_unsigned(funct12, 12));
        instruction(19 downto 15) := (others => '0');
        instruction(14 downto 12) := std_logic_vector(to_unsigned(funct3, 3));
        instruction(11 downto 7) := (others => '0');
        instruction(6 downto 0) := std_logic_vector(to_unsigned(opcode, 7));
        return instruction;
    end function;

end package body;
