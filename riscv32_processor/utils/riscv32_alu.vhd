library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_alu is
    port (
        inputA : in riscv32_data_type;
        inputB : in riscv32_data_type;
        shamt : in riscv32_shamt_type;
        cmd : in riscv32_alu_cmd;

        output : out riscv32_data_type
    );
end entity;

architecture behaviourial of riscv32_alu is
begin
    process(inputA, inputB, shamt, cmd)
        variable additionResult : riscv32_data_type;
        variable subtractionResult : riscv32_data_type;
        variable andResult : riscv32_data_type;
        variable orResult : riscv32_data_type;
        variable xorResult : riscv32_data_type;
        variable luiResult : riscv32_data_type;
        variable setLessThanResult : std_logic;
        variable setLessThanUnsignedResult : std_logic;
    begin
        additionResult := std_logic_vector(signed(inputA) + signed(inputB));
        subtractionResult := std_logic_vector(signed(inputA) - signed(inputB));
        andResult := inputA and inputB;
        orResult := inputA or inputB;
        xorResult := inputA xor inputB;
        if signed(inputA) < signed(inputB) then
            setLessThanResult := '1';
        else
            setLessThanResult := '0';
        end if;

        if unsigned(inputA) < unsigned(inputB) then
            setLessThanUnsignedResult := '1';
        else
            setLessThanUnsignedResult := '0';
        end if;

        case cmd is
            when cmd_alu_add =>
                output <= additionResult;
            when cmd_alu_sub =>
                output <= subtractionResult;
            when cmd_alu_and =>
                output <= andResult;
            when cmd_alu_or =>
                output <= orResult;
            when cmd_alu_xor =>
                output <= xorResult;
            when cmd_alu_slt =>
                output(output'high downto 1) <= (others => '0');
                output(0) <= setLessThanResult;
            when cmd_alu_sltu =>
                output(output'high downto 1) <= (others => '0');
                output(0) <= setLessThanUnsignedResult;
            when cmd_alu_sll =>
                output <= std_logic_vector(shift_left(unsigned(inputA), shamt));
            when cmd_alu_srl =>
                output <= std_logic_vector(shift_right(unsigned(inputA), shamt));
            when cmd_alu_sra =>
                output <= std_logic_vector(shift_right(signed(inputA), shamt));
        end case;
    end process;

end architecture;
