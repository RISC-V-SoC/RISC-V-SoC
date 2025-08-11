library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_csr_machine_trap_setup is
    port (
        clk : in std_logic;
        rst : in boolean;
        mst2slv : in riscv32_csr_mst2slv_type;
        slv2mst : out riscv32_csr_slv2mst_type;

        machine_interrupts_enabled : out boolean;
        interrupt_trigger : in boolean;
        interrupt_resolved : in boolean;

        machine_timer_interrupt_enabled : out boolean;
        machine_external_interrupt_enabled : out boolean;

        interrupt_base_address : out riscv32_address_type
    );
end entity;

architecture behaviourial of riscv32_csr_machine_trap_setup is
    constant mstatus_address : natural range 0 to 255 := 0;
    constant mstatus_default : riscv32_data_type := (others => '0');
    signal mstatus : riscv32_data_type := mstatus_default;
    alias mstatus_wpri_0 : std_logic is mstatus(0);
    -- Supervisor interrupt enable. Does not do much, since we are not implementing supervisor mode
    alias mstatus_sie : std_logic is mstatus(1);
    alias mstatus_wpri_2 : std_logic is mstatus(2);
    -- Machine interrupt enable
    alias mstatus_mie : std_logic is mstatus(3);
    alias mstatus_wpri_4 : std_logic is mstatus(4);
    -- Supervisor previous interrupt enable. Does not do much, since we are not implementing supervisor mode
    alias mstatus_spie : std_logic is mstatus(5);
    -- Use big endian. Force 0, since we are not implementing big endian
    alias mstatus_ube : std_logic is mstatus(6);
    -- Machine previous interrupt enable
    alias mstatus_mpie : std_logic is mstatus(7);
    -- Supervisor previous privilege level. Does not do much, since we are not implementing supervisor mode
    alias mstatus_spp : std_logic is mstatus(8);
    -- Extension context related. read-only zero
    alias mstatus_vs : std_logic_vector(1 downto 0) is mstatus(10 downto 9);
    -- Machine previous privilege level
    alias mstatus_mpp : std_logic_vector(1 downto 0) is mstatus(12 downto 11);
    -- Extension context related. Read-only zero
    alias mstatus_fs : std_logic_vector(1 downto 0) is mstatus(14 downto 13);
    -- Extension context related. Read-only zero
    alias mstatus_xs : std_logic_vector(1 downto 0) is mstatus(16 downto 15);
    -- Memory privilege mode. Read-only zero
    alias mstatus_mprv : std_logic is mstatus(17);
    -- Permit supervisor user memory access. Read-only zero, we have no S mode
    alias mstatus_sum : std_logic is mstatus(18);
    -- Make eXecutable Readable. Read-only zero, we have no S mode
    alias mstatus_mxr : std_logic is mstatus(19);
    -- Trap Virtual Memory. Read-only zero, we have no S mode
    alias mstatus_tvm : std_logic is mstatus(20);
    -- Timeout Wait. Read-only zero, because we have no WFI yet
    alias mstatus_tw : std_logic is mstatus(21);
    -- Trap SRET. Read-only zero, because we have no S mode
    alias mstatus_tsr : std_logic is mstatus(22);
    alias mstatus_wpri_30_23 : std_logic_vector(7 downto 0) is mstatus(30 downto 23);
    -- Extension context related. Read-only zero
    alias mstatus_sd : std_logic is mstatus(31);

    constant misa_address : natural range 0 to 255 := 1;
    constant misa_default : riscv32_data_type := X"40001100";
    signal misa : riscv32_data_type := misa_default;
    alias misa_extensions : std_logic_vector(25 downto 0) is misa(25 downto 0);
    alias misa_warl_29_26 : std_logic_vector(3 downto 0) is misa(29 downto 26);
    alias misa_mxl : std_logic_vector(1 downto 0) is misa(31 downto 30);

    constant mie_address : natural range 0 to 255 := 4;
    constant mie_default : riscv32_data_type := (others => '0');
    signal mie : riscv32_data_type := mie_default;
    alias mie_wpri_0 : std_logic is mie(0);
    -- Supervisor software interrupt, readonly zero
    alias mie_ssie : std_logic is mie(1);
    alias mie_wpri_2 : std_logic is mie(2);
    -- Machine software interrupt, readonly zero
    alias mie_msie : std_logic is mie(3);
    alias mie_wpri_4 : std_logic is mie(4);
    -- Supervisor timer interrupt, readonly zero
    alias mie_stie : std_logic is mie(5);
    alias mie_wpri_6 : std_logic is mie(6);
    -- Machine timer interrupt
    alias mie_mtie : std_logic is mie(7);
    alias mie_wpri_8 : std_logic is mie(8);
    -- Supervisor external interrupt, readonly zero
    alias mie_seie : std_logic is mie(9);
    alias mie_wpri_10 : std_logic is mie(10);
    -- Machine external interrupt
    alias mie_meie : std_logic is mie(11);
    alias mie_wpri_15_12 : std_logic_vector(3 downto 0) is mie(15 downto 12);
    alias mie_wpri_31_16 : std_logic_vector(15 downto 0) is mie(31 downto 16);

    constant mtvec_address : natural range 0 to 255 := 5;
    constant mtvec_default : riscv32_data_type := X"00000001";
    signal mtvec : riscv32_data_type := mtvec_default;
    alias mtvec_mode : std_logic_vector(1 downto 0) is mtvec(1 downto 0);
    alias mtvec_base : std_logic_vector(31 downto 2) is mtvec(31 downto 2);

    constant mstatush_address : natural range 0 to 255 := 16#10#;
    constant mstatush_default : riscv32_data_type := (others => '0');
    signal mstatush : riscv32_data_type := mstatush_default;
    alias mstatush_wpri_3_0 : std_logic_vector(3 downto 0) is mstatush(3 downto 0);
    -- No supervisor mode, therefore readonly zero
    alias mstatush_sbe : std_logic is mstatush(4);
    -- No dynamic endianess support, therefore readonly zero
    alias mstatush_mbe : std_logic is mstatush(5);
    alias mstatush_wpri_31_6 : std_logic_vector(25 downto 0) is mstatush(31 downto 6);

begin
    machine_interrupts_enabled <= mstatus_mie = '1';
    machine_timer_interrupt_enabled <= mie_mtie = '1';
    machine_external_interrupt_enabled <= mie_meie = '1';
    interrupt_base_address <= (interrupt_base_address'high downto 2 => mtvec_base, others => '0');

    read_handling : process(mst2slv, mstatus, misa, mie, mtvec, mstatush)
    begin
        slv2mst.has_error <= false;
        if mst2slv.address = mstatus_address then
            slv2mst.read_data <= mstatus;
        elsif mst2slv.address = misa_address then
            slv2mst.read_data <= misa;
        elsif mst2slv.address = mie_address then
            slv2mst.read_data <= mie;
        elsif mst2slv.address = mtvec_address then
            slv2mst.read_data <= mtvec;
        elsif mst2slv.address = mstatush_address then
            slv2mst.read_data <= mstatush;
        else
            slv2mst.read_data <= (others => '-');
            slv2mst.has_error <= true;
        end if;
    end process;

    mstatus_handling : process(clk)
    begin
        if rising_edge(clk) then
            if mst2slv.do_write and mst2slv.address = mstatus_address then
                mstatus <= mst2slv.write_data;
            end if;

            if interrupt_trigger then
                mstatus_mpie <= mstatus_mie;
                mstatus_mie <= '0';
                mstatus_mpp <= riscv32_privilege_level_machine;
            end if;

            if interrupt_resolved then
                mstatus_mie <= mstatus_mpie;
                mstatus_mpie <= '1';
                mstatus_mpp <= (others => '0');
            end if;

            if rst then
                mstatus <= mstatus_default;
            end if;

            mstatus_wpri_0 <= '0';
            mstatus_wpri_2 <= '0';
            mstatus_wpri_4 <= '0';
            mstatus_ube <= '0';
            mstatus_vs <= (others => '0');
            mstatus_fs <= (others => '0');
            mstatus_xs <= (others => '0');
            mstatus_mprv <= '0';
            mstatus_sum <= '0';
            mstatus_mxr <= '0';
            mstatus_tvm <= '0';
            mstatus_tw <= '0';
            mstatus_tsr <= '0';
            mstatus_wpri_30_23 <= (others => '0');
            mstatus_sd <= '0';
        end if;
    end process;

    mie_handling : process(clk)
    begin
        if rising_edge(clk) then
            if mst2slv.do_write and mst2slv.address = mie_address then
                mie <= mst2slv.write_data;
            end if;

            if rst then
                mie <= mie_default;
            end if;

            mie_wpri_0 <= '0';
            mie_ssie <= '0';
            mie_wpri_2 <= '0';
            mie_msie <= '0';
            mie_wpri_4 <= '0';
            mie_stie <= '0';
            mie_wpri_6 <= '0';
            mie_wpri_8 <= '0';
            mie_seie <= '0';
            mie_wpri_10 <= '0';
            mie_wpri_15_12 <= (others => '0');
            mie_wpri_31_16 <= (others => '0');
        end if;
    end process;

    mtvec_handling : process(clk)
    begin
        if rising_edge(clk) then
            if mst2slv.do_write and mst2slv.address = mtvec_address then
                mtvec <= mst2slv.write_data;
            end if;

            if rst then
                mtvec <= mtvec_default;
            end if;
            mtvec_mode <= "01";
        end if;
    end process;
end architecture;
