library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;
use work.riscv32_pkg.all;

entity riscv32_pipeline_register is
    port (
        -- To previous stages: control
        repeatInstruction : out boolean;

        -- Control input
        execControlWord : in riscv32_ExecuteControlWord_type;
        writeBackControlWord : in riscv32_WriteBackControlWord_type;
        regExWriteBackControlWord : in riscv32_WriteBackControlWord_type;
        exMemWriteBackControlWord : in riscv32_WriteBackControlWord_type;

        -- Data input
        regExRdAddress : in riscv32_registerFileAddress_type;
        exMemRdAddress : in riscv32_registerFileAddress_type;
        exMemExecResult : in riscv32_data_type;
        rs1Address : in riscv32_registerFileAddress_type;
        rs2Address : in riscv32_registerFileAddress_type;
        rs1DataFromRegFile : in riscv32_data_type;
        rs2DataFromRegFile : in riscv32_data_type;

        -- Data output
        rs1DataOut : out riscv32_data_type;
        rs2dataOut : out riscv32_data_type
    );
end entity;

architecture behaviourial of riscv32_pipeline_register is
    signal rs1Hazard : boolean := false;
    signal rs2Hazard : boolean := false;

    signal regExOpDoesStore : boolean := false;
    signal exMemOpIsMemLoad : boolean := false;
    signal exMemOpDoesStore : boolean := false;

begin
    regExOpDoesStore <= regExWriteBackControlWord.regWrite;
    exMemOpIsMemLoad <= exMemWriteBackControlWord.memToReg;
    exMemOpDoesStore <= exMemWriteBackControlWord.regWrite;

    determineHazard : process(exMemOpIsMemLoad, regExOpDoesStore, rs1Address, rs2Address, regExRdAddress, exMemRdAddress) is
        impure function hasHazard (address : riscv32_registerFileAddress_type) return boolean is
        begin
            if address = 0 then
                return false;
            elsif address = regExRdAddress and regExOpDoesStore then
                return true;
            elsif address = exMemRdAddress and exMemOpIsMemLoad then
                return true;
            else
                return false;
            end if;
        end function;
    begin
        rs1Hazard <= hasHazard(rs1Address);
        rs2Hazard <= hasHazard(rs2Address);
    end process;

    repeatInstruction <= (rs1Hazard or rs2Hazard);

    determineForwarding : process(rs1Address, rs1DataFromRegFile, rs2Address, rs2DataFromRegFile, exMemExecResult, exMemRdAddress, exMemOpDoesStore)
        impure function forwardData (address : riscv32_registerFileAddress_type; regData : riscv32_data_type) return riscv32_data_type is
        begin
            if address = 0 then
                return std_logic_vector'(X"00000000");
            elsif exMemRdAddress = address and exMemOpDoesStore then
                return exMemExecResult;
            else
                return regData;
            end if;
        end function;
    begin
        rs1DataOut <= forwardData(rs1Address, rs1DataFromRegFile);
        rs2DataOut <= forwardData(rs2Address, rs2DataFromRegFile);
    end process;
end architecture;
