library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;
use work.riscv32_pkg.all;

entity riscv32_pipeline_instructionFetch is
    generic (
        startAddress : riscv32_address_type
    );
    port (
        clk : in std_logic;
        rst : in boolean;
        enable : in boolean;
        stall : in boolean;

        -- To/from bus controller
        requestFromBusAddress : out riscv32_address_type;
        requestFromBusEnable : out boolean;

        -- From instructionDecode (unconditional jump)
        overrideProgramCounterFromID : in boolean;
        newProgramCounterFromID : in riscv32_address_type;

        -- From execute (unconditional jump or branch)
        overrideProgramCounterFromEx : in boolean;
        newProgramCounterFromEx : in riscv32_address_type;

        -- From interrupt control
        overrideProgramCounterFromInterrupt : in boolean;
        newProgramCounterFromInterrupt : in riscv32_address_type
    );
end entity;

architecture behaviourial of riscv32_pipeline_instructionFetch is
begin
    process(clk)
        variable current_pc : riscv32_address_type := startAddress;
    begin
        if rising_edge(clk) then
            if rst then
                current_pc := startAddress;
            elsif overrideProgramCounterFromEx then
                current_pc := newProgramCounterFromEx;
            elsif overrideProgramCounterFromID then
                current_pc := newProgramCounterFromID;
            elsif overrideProgramCounterFromInterrupt then
                current_pc := newProgramCounterFromInterrupt;
            elsif enable and not stall then
                current_pc := std_logic_vector(unsigned(current_pc) + 4);
            end if;
        end if;
        requestFromBusAddress <= current_pc;
    end process;
    requestFromBusEnable <= enable;
end architecture;
