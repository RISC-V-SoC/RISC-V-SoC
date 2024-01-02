library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_pipeline_loadHazardDetector is
    port (
        writeBackControlWordFromEx : in riscv32_WriteBackControlWord_type;
        targetRegFromEx : in riscv32_registerFileAddress_type;
        readPortOneAddressFromID : in riscv32_registerFileAddress_type;
        readPortTwoAddressFromID : in riscv32_registerFileAddress_type;

        loadHazardDetected : out boolean
    );
end entity;

architecture behaviourial of riscv32_pipeline_loadHazardDetector is
    signal loadHazardPortOne : boolean;
    signal loadHazardPortTwo : boolean;
begin
    loadHazardPortOne <= targetRegFromEx = readPortOneAddressFromID;
    loadHazardPortTwo <= targetRegFromEx = readPortTwoAddressFromID;

    loadHazardDetected <= (loadHazardPortOne or loadHazardPortTwo) and writeBackControlWordFromEx.memToReg and targetRegFromEx /= 0;
end architecture;
