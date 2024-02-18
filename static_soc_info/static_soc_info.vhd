library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.bus_pkg;

entity static_soc_info is
    generic (
        clk_freq_hz : natural
    );
    port (
        clk : in std_logic;

        mst2slv : in bus_pkg.bus_mst2slv_type;
        slv2mst : out bus_pkg.bus_slv2mst_type
    );
end entity;

architecture behavioral of static_soc_info is
    signal slv2mst_buf : bus_pkg.bus_slv2mst_type;
begin

    slv2mst <= slv2mst_buf;

    process (clk)
        variable slv2mst_tmp : bus_pkg.bus_slv2mst_type := bus_pkg.BUS_SLV2MST_IDLE;
        variable answer_ready : boolean := false;
        variable address : natural range 0 to 3;
    begin
        if rising_edge(clk) then
            if bus_pkg.any_transaction(mst2slv, slv2mst_buf) then
                slv2mst_buf <= bus_pkg.BUS_SLV2MST_IDLE;
                slv2mst_tmp := bus_pkg.BUS_SLV2MST_IDLE;
            elsif answer_ready then
                slv2mst_buf <= slv2mst_tmp;
                answer_ready := false;
            elsif bus_pkg.bus_requesting(mst2slv) then
                address := to_integer(unsigned(mst2slv.address(1 downto 0)));
                slv2mst_tmp.readData := std_logic_vector(to_unsigned(clk_freq_hz, slv2mst_tmp.readData'length));
                slv2mst_tmp.readData := std_logic_vector(shift_right(unsigned(slv2mst_tmp.readData), address*8));
                slv2mst_tmp.valid := true;
                answer_ready := true;
            end if;
        end if;
    end process;


end architecture;
