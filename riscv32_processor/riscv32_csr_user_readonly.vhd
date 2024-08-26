library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_csr_user_readonly is
    port (
        cycleCounter_value : in unsigned(63 downto 0);
        systemtimer_value : in unsigned(63 downto 0);
        instructionsRetired_value : in unsigned(63 downto 0);

        mst2slv : in riscv32_csr_mst2slv_type;
        slv2mst : out riscv32_csr_slv2mst_type
    );
end entity;

architecture behaviourial of riscv32_csr_user_readonly is
    signal low_array : riscv32_data_array(2 downto 0);
    signal high_array : riscv32_data_array(2 downto 0);

    signal read_high : boolean;
    signal partial_address : natural range 0 to 127;
begin
    read_high <= mst2slv.address >= 16#80#;
    partial_address <= mst2slv.address mod 128;

    low_array(0) <= std_logic_vector(cycleCounter_value(31 downto 0));
    low_array(1) <= std_logic_vector(systemtimer_value(31 downto 0));
    low_array(2) <= std_logic_vector(instructionsRetired_value(31 downto 0));

    high_array(0) <= std_logic_vector(cycleCounter_value(63 downto 32));
    high_array(1) <= std_logic_vector(systemtimer_value(63 downto 32));
    high_array(2) <= std_logic_vector(instructionsRetired_value(63 downto 32));

    process(read_high, low_array, high_array, partial_address)
    begin
        slv2mst.has_error <= partial_address > low_array'high;
        if partial_address <= low_array'high then
            if read_high then
                slv2mst.read_data <= high_array(partial_address);
            else
                slv2mst.read_data <= low_array(partial_address);
            end if;
        else
            slv2mst.read_data <= (others => '-');
        end if;
    end process;
end architecture;
