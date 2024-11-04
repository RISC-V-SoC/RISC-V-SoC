library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg.all;
use work.riscv32_pkg.all;

entity riscv32_memToBus_bus_interaction is
    port (
        clk : in std_logic;
        rst : in boolean;

        mst2slv : out bus_mst2slv_type;
        slv2mst : in bus_slv2mst_type;

        readAddress : in bus_address_type;
        writeAddress : in bus_address_type;
        readByteMask : in bus_byte_mask_type;
        writeByteMask : in bus_byte_mask_type;
        doRead : in boolean;
        doWrite : in boolean;
        dataIn : in bus_data_type;

        busy : out boolean;
        completed : out boolean;
        fault : out boolean;
        dataOut : out bus_data_type;
        faultData : out bus_fault_type
    );
end entity;

architecture behaviourial of riscv32_memToBus_bus_interaction is
begin
    process(clk)
        variable mst2slv_buf : bus_mst2slv_type := BUS_MST2SLV_IDLE;
    begin
        if rising_edge(clk) then
            if rst then
                mst2slv_buf := BUS_MST2SLV_IDLE;
                busy <= false;
                completed <= false;
                fault <= false;
            elsif any_transaction(mst2slv_buf, slv2mst) then
                busy <= false;
                completed <= true;
                fault <= slv2mst.fault = '1';
                dataOut <= slv2mst.readData;
                faultData <= slv2mst.faultData;
                mst2slv_buf := BUS_MST2SLV_IDLE;
            elsif bus_requesting(mst2slv_buf) then
                busy <= true;
                completed <= false;
                fault <= false;
            elsif doRead then
                mst2slv_buf := bus_mst2slv_read(readAddress, readByteMask);
                busy <= true;
                completed <= false;
                fault <= false;
            elsif doWrite then
                mst2slv_buf := bus_mst2slv_write(writeAddress, dataIn, writeByteMask);
                busy <= true;
                completed <= false;
                fault <= false;
            else
                busy <= false;
                completed <= false;
                fault <= false;
            end if;
        end if;
        mst2slv <= mst2slv_buf;
    end process;

end architecture;
