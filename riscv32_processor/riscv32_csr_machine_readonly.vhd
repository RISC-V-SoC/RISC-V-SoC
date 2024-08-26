library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_csr_machine_readonly is
    port (
        mst2slv : in riscv32_csr_mst2slv_type;
        slv2mst : out riscv32_csr_slv2mst_type
    );
end entity;

architecture behaviourial of riscv32_csr_machine_readonly is
    constant mvendorid : riscv32_data_type := X"00000000";
    constant marchid : riscv32_data_type := X"00000000";
    constant mimpid : riscv32_data_type := X"00000000";
    constant mhartid : riscv32_data_type := X"00000000";
    constant mconfigptr : riscv32_data_type := X"00000000";

    constant ro_array : riscv32_data_array(4 downto 0) := (
        mvendorid, -- 0x11
        marchid,   -- 0x12
        mimpid,    -- 0x13
        mhartid,   -- 0x14
        mconfigptr -- 0x15
    );

begin
    process(mst2slv)
    begin
        slv2mst.has_error <= mst2slv.address < 16#11# or mst2slv.address > 16#15#;
        if mst2slv.address >= 16#11# and mst2slv.address <= 16#15# then
            slv2mst.read_data <= ro_array(mst2slv.address - 16#11#);
        else
            slv2mst.read_data <= (others => '-');
        end if;
    end process;
end architecture;
