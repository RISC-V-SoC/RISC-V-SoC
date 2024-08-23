library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package riscv32_pkg is
    constant riscv32_address_width_log2b : natural := 5;
    constant riscv32_data_width_log2b : natural := 5;
    constant riscv32_instruction_width_log2b : natural := 5;
    constant riscv32_byte_width_log2b : natural := 3;

    constant riscv32_bytes_per_data_word : natural := 2**(riscv32_data_width_log2b - riscv32_byte_width_log2b);

    constant riscv32_byte_width : natural := 2**riscv32_byte_width_log2b;

    subtype riscv32_address_type is std_logic_vector(2**riscv32_address_width_log2b - 1 downto  0);
    subtype riscv32_csr_address_type is std_logic_vector(11 downto 0);
    subtype riscv32_data_type is std_logic_vector(2**riscv32_data_width_log2b -1 downto 0);
    subtype riscv32_instruction_type is std_logic_vector(2**riscv32_instruction_width_log2b - 1 downto 0);
    subtype riscv32_byte_type is std_logic_vector(2**riscv32_byte_width_log2b - 1 downto 0);
    subtype riscv32_opcode_type is natural range 0 to 127;
    subtype riscv32_funct7_type is natural range 0 to 127;
    subtype riscv32_funct3_type is natural range 0 to 7;
    subtype riscv32_registerFileAddress_type is natural range 0 to 31;
    subtype riscv32_shamt_type is natural range 0 to 31;
    subtype riscv32_byte_mask_type is std_logic_vector(riscv32_bytes_per_data_word - 1 downto 0);

    type riscv32_data_array is array (natural range <>) of riscv32_data_type;
    type riscv32_instruction_array is array (natural range <>) of riscv32_instruction_type;
    type riscv32_byte_array is array (natural range <>) of riscv32_byte_type;
    type riscv32_load_store_size is (ls_word, ls_halfword, ls_byte);

    type riscv32_immidiate_type is (riscv32_i_immidiate, riscv32_u_immidiate, riscv32_b_immidiate, riscv32_s_immidiate);
    type riscv32_exec_type is (riscv32_exec_alu_imm, riscv32_exec_alu_rtype, riscv32_exec_calcReturn, riscv32_exec_lui, riscv32_exec_auipc);
    type riscv32_alu_cmd is (cmd_alu_add, cmd_alu_slt, cmd_alu_sltu, cmd_alu_and, cmd_alu_or, cmd_alu_xor, cmd_alu_sub, cmd_alu_sll, cmd_alu_srl, cmd_alu_sra);
    type riscv32_branch_cmd is (cmd_branch_eq, cmd_branch_ne, cmd_branch_lt, cmd_branch_ltu, cmd_branch_ge, cmd_branch_geu, cmd_branch_jalr);
    type riscv32_csr_cmd is (csr_rw, csr_rs, csr_rc);

    type riscv32_to_csr_type is record
        command : riscv32_csr_cmd;
        address : riscv32_csr_address_type;
        data_in : riscv32_data_type;
        do_write : boolean;
        do_read : boolean;
    end record;

    type riscv32_InstructionDecodeControlWord_type is record
        jump : boolean;
        PCSrc : boolean;
        immidiate_type : riscv32_immidiate_type;
    end record;

    type riscv32_RegisterControlWord_type is record
        no_dependencies : boolean;
        ignore_rs2_dependencies : boolean;
    end record;

    type riscv32_ExecuteControlWord_type is record
        exec_directive : riscv32_exec_type;
        is_branch_op : boolean;
        alu_cmd : riscv32_alu_cmd;
        branch_cmd : riscv32_branch_cmd;
    end record;

    type riscv32_MemoryControlWord_type is record
        MemOp : boolean;
        MemOpIsWrite : boolean;
        memReadSignExtend : boolean;
        loadStoreSize : riscv32_load_store_size;
        csrOp : boolean;
        csrCmd : riscv32_csr_cmd;
        csrRead : boolean;
        csrWrite : boolean;
        csrUseUimm : boolean;
    end record;

    type riscv32_WriteBackControlWord_type is record
        regWrite : boolean;
        MemtoReg : boolean;
    end record;

    type riscv32_ExecuteControlWord_array is array (natural range <>) of riscv32_ExecuteControlWord_type;

    type riscv32_csr_mapping_type is record
        address_low : natural range 0 to 4095;
        mapping_size : natural range 0 to 4095;
    end record;

    type riscv32_csr_mapping_array is array (natural range <>) of riscv32_csr_mapping_type;

    type riscv32_csr_mst2slv_type is record
        address : natural range 0 to 255;
        write_data : riscv32_data_type;
        do_write : boolean;
        do_read : boolean;
    end record;

    type riscv32_csr_mst2slv_array is array (natural range <>) of riscv32_csr_mst2slv_type;

    type riscv32_csr_slv2mst_type is record
        read_data : riscv32_data_type;
        has_error : boolean;
    end record;

    type riscv32_csr_slv2mst_array is array (natural range <>) of riscv32_csr_slv2mst_type;

    constant riscv32_registerControlWordAllFalse : riscv32_RegisterControlWord_type := (
        no_dependencies => false,
        ignore_rs2_dependencies => false
    );

    constant riscv32_instructionDecodeControlWordAllFalse : riscv32_InstructionDecodeControlWord_type := (
        jump => false,
        PCSrc => false,
        immidiate_type => riscv32_i_immidiate
    );

    constant riscv32_executeControlWordAllFalse : riscv32_ExecuteControlWord_type := (
        exec_directive => riscv32_exec_alu_imm,
        is_branch_op => false,
        alu_cmd => cmd_alu_add,
        branch_cmd => cmd_branch_eq
    );

    constant riscv32_memoryControlWordAllFalse : riscv32_MemoryControlWord_type := (
        MemOp => false,
        MemOpIsWrite => false,
        memReadSignExtend => false,
        loadStoreSize => ls_word,
        csrOp => false,
        csrCmd => csr_rw,
        csrRead => false,
        csrWrite => false,
        csrUseUimm => false
    );

    constant riscv32_writeBackControlWordAllFalse : riscv32_WriteBackControlWord_type := (
        regWrite => false,
        MemtoReg => false
    );

    -- The nop is addi x0,x0,0
    constant riscv32_instructionNop : riscv32_instruction_type := X"00000013";

    constant riscv32_opcode_load : riscv32_opcode_type := 16#3#;
    constant riscv32_opcode_opimm : riscv32_opcode_type := 16#13#;
    constant riscv32_opcode_auipc : riscv32_opcode_type := 16#17#;
    constant riscv32_opcode_miscmem : riscv32_opcode_type := 16#1f#;
    constant riscv32_opcode_store : riscv32_opcode_type := 16#23#;
    constant riscv32_opcode_op : riscv32_opcode_type := 16#33#;
    constant riscv32_opcode_lui : riscv32_opcode_type := 16#37#;
    constant riscv32_opcode_branch : riscv32_opcode_type := 16#63#;
    constant riscv32_opcode_jalr : riscv32_opcode_type := 16#67#;
    constant riscv32_opcode_jal : riscv32_opcode_type := 16#6f#;
    constant riscv32_opcode_system : riscv32_opcode_type := 16#73#;

    constant riscv32_funct3_add_sub : riscv32_funct3_type := 16#0#;
    constant riscv32_funct3_sll : riscv32_funct3_type := 16#1#;
    constant riscv32_funct3_slt : riscv32_funct3_type := 16#2#;
    constant riscv32_funct3_sltu : riscv32_funct3_type := 16#3#;
    constant riscv32_funct3_xor : riscv32_funct3_type := 16#4#;
    constant riscv32_funct3_srl_sra : riscv32_funct3_type := 16#5#;
    constant riscv32_funct3_or : riscv32_funct3_type := 16#6#;
    constant riscv32_funct3_and : riscv32_funct3_type := 16#7#;

    constant riscv32_funct7_srl : riscv32_funct7_type := 16#0#;
    constant riscv32_funct7_sra : riscv32_funct7_type := 16#20#;

    constant riscv32_funct7_add : riscv32_funct7_type := 16#0#;
    constant riscv32_funct7_sub : riscv32_funct7_type := 16#20#;

    constant riscv32_funct3_beq : riscv32_funct3_type := 16#0#;
    constant riscv32_funct3_bne : riscv32_funct3_type := 16#1#;
    constant riscv32_funct3_blt : riscv32_funct3_type := 16#4#;
    constant riscv32_funct3_bge : riscv32_funct3_type := 16#5#;
    constant riscv32_funct3_bltu : riscv32_funct3_type := 16#6#;
    constant riscv32_funct3_bgeu : riscv32_funct3_type := 16#7#;

    constant riscv32_funct3_lb : riscv32_funct3_type := 16#0#;
    constant riscv32_funct3_lh : riscv32_funct3_type := 16#1#;
    constant riscv32_funct3_lw : riscv32_funct3_type := 16#2#;
    constant riscv32_funct3_lbu : riscv32_funct3_type := 16#4#;
    constant riscv32_funct3_lhu : riscv32_funct3_type := 16#5#;

    constant riscv32_funct3_sb : riscv32_funct3_type := 16#0#;
    constant riscv32_funct3_sh : riscv32_funct3_type := 16#1#;
    constant riscv32_funct3_sw : riscv32_funct3_type := 16#2#;

    constant riscv32_funct3_fence : riscv32_funct3_type := 16#0#;

    constant riscv32_funct7_ecall : riscv32_funct7_type := 16#0#;
    constant riscv32_funct7_ebreak : riscv32_funct7_type := 16#1#;

    -- Zicsr extension
    constant riscv32_funct3_csrrw : riscv32_funct3_type := 16#1#;
    constant riscv32_funct3_csrrs : riscv32_funct3_type := 16#2#;
    constant riscv32_funct3_csrrc : riscv32_funct3_type := 16#3#;
    constant riscv32_funct3_csrrwi : riscv32_funct3_type := 16#5#;
    constant riscv32_funct3_csrrsi : riscv32_funct3_type := 16#6#;
    constant riscv32_funct3_csrrci : riscv32_funct3_type := 16#7#;

    constant riscv32_privilege_level_user : std_logic_vector(1 downto 0) := "00";
    constant riscv32_privilege_level_supervisor : std_logic_vector(1 downto 0) := "01";
    constant riscv32_privilege_level_machine : std_logic_vector(1 downto 0) := "11";

end package;
