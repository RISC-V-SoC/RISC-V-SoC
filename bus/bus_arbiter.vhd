library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.bus_pkg;

entity bus_arbiter is
    generic (
        masterCount : natural range 1 to natural'high
    );
    port (
        clk : in std_logic;

        mst2arbiter : in bus_pkg.bus_mst2slv_array(0 to masterCount - 1);
        arbiter2mst : out bus_pkg.bus_slv2mst_array(0 to masterCount - 1);

        arbiter2slv : out bus_pkg.bus_mst2slv_type;
        slv2arbiter : in bus_pkg.bus_slv2mst_type
    );
end bus_arbiter;

architecture behaviourial of bus_arbiter is
    signal selectedMaster : natural range 0 to masterCount - 1 := 0;

    impure function next_master(
        currentMaster : natural range 0 to masterCount - 1
    ) return natural is
        variable checkingMaster : natural;
    begin
        for i in 0 to masterCount - 1 loop
            checkingMaster := i + currentMaster;
            if checkingMaster > masterCount - 1 then
                checkingMaster := checkingMaster - masterCount;
            end if;

            if bus_pkg.bus_mst_active(mst2arbiter(checkingMaster)) then
                return checkingMaster;
            end if;
        end loop;
        return currentMaster;
    end function;
begin
    combinatoral : process(mst2arbiter, slv2arbiter, selectedMaster)
    begin
        arbiter2slv <= mst2arbiter(selectedMaster);
        for i in 0 to masterCount - 1 loop
            if i = selectedMaster then
                arbiter2mst(i) <= slv2arbiter;
            else
                arbiter2mst(i) <= bus_pkg.BUS_SLV2MST_IDLE;
            end if;
        end loop;
    end process;

    sequential : process(clk)
    begin
        if rising_edge(clk) then
            if not bus_pkg.bus_mst_active(mst2arbiter(selectedMaster)) then
                selectedMaster <= next_master(selectedMaster);
            end if;
        end if;
    end process;

end architecture;
