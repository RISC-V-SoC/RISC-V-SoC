library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_multiplier is
    port (
        inputA : in riscv32_data_type;
        inputB : in riscv32_data_type;

        outputWordHigh : in boolean;
        inputASigned : in boolean;
        inputBSigned : in boolean;

        output : out riscv32_data_type
    );
end entity;

architecture behaviourial of riscv32_multiplier is
begin
    process(inputA, inputB, outputWordHigh, inputASigned, inputBSigned)
        variable multiplicationResult : std_logic_vector(63 downto 0);
        variable signExtendedInputA : signed(inputA'high + 1 downto 0);
        variable signExtendedInputB : signed(inputB'high + 1 downto 0);
    begin
        if inputASigned then
            signExtendedInputA := resize(signed(inputA), signExtendedInputA'length);
        else
            signExtendedInputA := signed('0' & inputA);
        end if;

        if inputBSigned then
            signExtendedInputB := resize(signed(inputB), signExtendedInputB'length);
        else
            signExtendedInputB := signed('0' & inputB);
        end if;

        multiplicationResult := std_logic_vector(resize(signExtendedInputA * signExtendedInputB, multiplicationResult'length));

        if outputWordHigh then
            output <= multiplicationResult(63 downto 32);
        else
            output <= multiplicationResult(31 downto 0);
        end if;
    end process;
end architecture;
