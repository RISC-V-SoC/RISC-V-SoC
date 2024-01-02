library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_pipeline_registerFile is
    port (
        clk : in std_logic;

        readPortOneAddress : in riscv32_registerFileAddress_type;
        readPortOneData : out riscv32_data_type;

        readPortTwoAddress : in riscv32_registerFileAddress_type;
        readPortTwoData : out riscv32_data_type;

        writePortDoWrite : in boolean;
        writePortAddress : in riscv32_registerFileAddress_type;
        writePortData : in riscv32_data_type;

        extPortAddress : in riscv32_registerFileAddress_type;
        readPortExtData : out riscv32_data_type;
        writePortExtDoWrite : in boolean;
        writePortExtData : in riscv32_data_type
    );
end entity;

architecture behaviourial of riscv32_pipeline_registerFile is
    signal registerFile : riscv32_data_array(1 to 31);
begin

    readPortOne : process(readPortOneAddress, writePortDoWrite, writePortAddress, writePortData, registerFile)
    begin
        if readPortOneAddress = 0 then
            readPortOneData <= (others => '0');
        elsif readPortOneAddress = writePortAddress and writePortDoWrite then
            readPortOneData <= writePortData;
        else
            readPortOneData <= registerFile(readPortOneAddress);
        end if;
    end process;

    readPortTwo : process(readPortTwoAddress, writePortDoWrite, writePortAddress, writePortData, registerFile)
    begin
        if readPortTwoAddress = 0 then
            readPortTwoData <= (others => '0');
        elsif readPortTwoAddress = writePortAddress and writePortDoWrite then
            readPortTwoData <= writePortData;
        else
            readPortTwoData <= registerFile(readPortTwoAddress);
        end if;
    end process;

    readPortExt : process(extPortAddress, registerFile)
    begin
        if extPortAddress = 0 then
            readPortExtData <= (others => '0');
        else
            readPortExtData <= registerFile(extPortAddress);
        end if;
    end process;

    writePort : process(clk)
    begin
        if rising_edge(clk) then
            if writePortExtDoWrite then
                if extPortAddress /= 0 then
                    registerFile(extPortAddress) <= writePortExtData;
                end if;
            elsif writePortAddress /= 0 and writePortDoWrite then
                registerFile(writePortAddress) <= writePortData;
            end if;
        end if;
    end process;

end behaviourial;
