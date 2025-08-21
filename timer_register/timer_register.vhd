library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.bus_pkg;

entity timer_register is
    generic (
        clk_period : time;
        timer_period : time
    );
    port (
        clk : in std_logic;
        reset : in boolean;

        timer_interrupt_pending : out boolean;

        mst2slv : in bus_pkg.bus_mst2slv_type;
        slv2mst : out bus_pkg.bus_slv2mst_type
    );
end entity;

architecture behaviourial of timer_register is
    signal slv2mst_buf : bus_pkg.bus_slv2mst_type := bus_pkg.BUS_SLV2MST_IDLE;
    signal timer_done : std_logic;
    signal combined : unsigned(127 downto 0) := (others => '0');
    alias mtime : unsigned(63 downto 0) is combined(63 downto 0);
    alias mtimecmp : unsigned(63 downto 0) is combined(127 downto 64);

    pure function to_std_logic(val : boolean) return std_logic is
    begin
        if val then
            return '1';
        else
            return '0';
        end if;
    end function;
begin
    slv2mst <= slv2mst_buf;
    timer_interrupt_pending <= mtime >= mtimecmp;

    process (clk)
        variable slv2mst_tmp : bus_pkg.bus_slv2mst_type := bus_pkg.BUS_SLV2MST_IDLE;
        variable base_address : natural;
        variable address : natural;
        variable data_byte : std_logic_vector(7 downto 0);
    begin
        if rising_edge(clk) then
            if timer_done then
                mtime <= mtime + 1;
            end if;

            if reset then
                slv2mst_buf <= bus_pkg.BUS_SLV2MST_IDLE;
                slv2mst_tmp := bus_pkg.BUS_SLV2MST_IDLE;
                combined <= (others => '0');
            elsif bus_pkg.any_transaction(mst2slv, slv2mst_buf) then
                slv2mst_buf <= bus_pkg.BUS_SLV2MST_IDLE;
                slv2mst_tmp := bus_pkg.BUS_SLV2MST_IDLE;
            elsif slv2mst_tmp.valid then
                slv2mst_buf <= slv2mst_tmp;
            elsif bus_pkg.bus_requesting(mst2slv) then
                base_address := to_integer(unsigned(mst2slv.address));
                for i in 0 to 3 loop
                    address := base_address + i;
                    if address > 15 then
                        exit;
                    end if;

                    if mst2slv.byteMask(i) = '0' then
                        next;
                    end if;

                    slv2mst_tmp.readData(i*8 + 7 downto i*8) := std_logic_vector(combined((address * 8) + 7 downto (address * 8)));
                    if mst2slv.writeReady = '1' then
                        data_byte := mst2slv.writeData(i*8 + 7 downto i*8);
                        combined((address * 8) + 7 downto (address * 8)) <= unsigned(data_byte);
                    end if;
                    slv2mst_tmp.valid := true;
                end loop;
            end if;
        end if;
    end process;

    timer : entity work.simple_multishot_timer
    generic map (
        match_val => timer_period / clk_period
    ) port map (
        clk => clk,
        rst => to_std_logic(reset),
        done => timer_done
    );
end architecture;
