library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_pipeline_forwarding_unit is
    port (
        rs1DataFromID : in riscv32_data_type;
        rs1AddressFromID : in riscv32_registerFileAddress_type;
        rs2DataFromID : in riscv32_data_type;
        rs2AddressFromID : in riscv32_registerFileAddress_type;

        regDataFromEx : in riscv32_data_type;
        regAddressFromEx : in riscv32_registerFileAddress_type;
        regWriteFromEx : in boolean;

        regDataFromMem : in riscv32_data_type;
        regAddressFromMem : in riscv32_registerFileAddress_type;
        regWriteFromMem : in boolean;

        rs1Data : out riscv32_data_type;
        rs2Data : out riscv32_data_type
    );
end entity;

architecture behaviourial of riscv32_pipeline_forwarding_unit is
begin
    determineRsData : process(rs1DataFromID, rs1AddressFromID, regDataFromEx, regAddressFromEx, regWriteFromEx,
                                regDataFromMem, regAddressFromMem, regWriteFromMem)
    begin
        if rs1AddressFromID = 0 then
            rs1Data <= (others => '0');
        elsif regWriteFromEx and rs1AddressFromID = regAddressFromEx then
            rs1Data <= regDataFromEx;
        elsif regWriteFromMem and rs1AddressFromID = regAddressFromMem then
            rs1Data <= regDataFromMem;
        else
            rs1Data <= rs1DataFromID;
        end if;
    end process;

    determineRtData : process(rs2DataFromID, rs2AddressFromID, regDataFromEx, regAddressFromEx, regWriteFromEx,
                                regDataFromMem, regAddressFromMem, regWriteFromMem)
    begin
        if rs2AddressFromID = 0 then
            rs2Data <= (others => '0');
        elsif regWriteFromEx and rs2AddressFromID = regAddressFromEx then
            rs2Data <= regDataFromEx;
        elsif regWriteFromMem and rs2AddressFromID = regAddressFromMem then
            rs2Data <= regDataFromMem;
        else
            rs2Data <= rs2DataFromID;
        end if;
    end process;
end architecture;
