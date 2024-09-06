library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_csr_machine_trap_handling is
    port (
        clk : in std_logic;
        rst : in boolean;
        mst2slv : in riscv32_csr_mst2slv_type;
        slv2mst : out riscv32_csr_slv2mst_type;

        m_timer_interrupt_pending : in boolean;
        m_external_interrupt_pending : in boolean;

        interrupt_is_async : in boolean;
        exception_code : in natural range 0 to 63;

        interrupted_pc : in riscv32_address_type;
        pc_on_return : out riscv32_address_type;

        interrupt_trigger : in boolean
    );
end entity;

architecture behaviourial of riscv32_csr_machine_trap_handling is
    constant mscratch_address : natural range 0 to 255 := 16#40#;
    constant mscratch_default : riscv32_data_type := (others => '0');
    signal mscratch : riscv32_data_type := mscratch_default;

    constant mepc_address : natural range 0 to 255 := 16#41#;
    constant mepc_default : riscv32_data_type := (others => '0');
    signal mepc : riscv32_data_type := mscratch_default;
    alias mepc_readonly_zero : std_logic_vector(1 downto 0) is mepc(1 downto 0);
    alias mepc_return_address : std_logic_vector(31 downto 2) is mepc(31 downto 2);

    constant mcause_address : natural range 0 to 255 := 16#42#;
    constant mcause_default : riscv32_data_type := (others => '0');
    signal mcause : riscv32_data_type := mcause_default;
    alias mcause_interrupt : std_logic is mcause(mcause'high);
    alias mcause_exception_code : std_logic_vector(mcause'high - 1 downto 0) is mcause(mcause'high - 1 downto 0);

    constant mtval_address : natural range 0 to 255 := 16#43#;
    constant mtval_default : riscv32_data_type := (others => '0');
    -- mtval is a read-only zero
    signal mtval : riscv32_data_type := mtval_default;

    constant mip_address : natural range 0 to 255 := 16#44#;
    constant mip_default : riscv32_data_type := (others => '0');
    signal mip : riscv32_data_type := mip_default;
    alias mip_wpri_0 : std_logic is mip(0);
    -- Supervisor software interrupt pending, readonly zero
    alias mip_ssip : std_logic is mip(1);
    alias mip_wpri_2 : std_logic is mip(2);
    -- Machine software interrupt pending, readonly zero
    alias mip_msip : std_logic is mip(3);
    alias mip_wpri_4 : std_logic is mip(4);
    -- Supervisor timer interrupt pending, readonly zero
    alias mip_stip : std_logic is mip(5);
    alias mip_wpri_6 : std_logic is mip(6);
    -- Machine timer interrupt pending
    alias mip_mtip : std_logic is mip(7);
    alias mip_wpri_8 : std_logic is mip(8);
    -- Supervisor external interrupt pending, readonly zero
    alias mip_seip : std_logic is mip(9);
    alias mip_wpri_10 : std_logic is mip(10);
    -- Machine external interrupt pending
    alias mip_meip : std_logic is mip(11);
    alias mip_wpri_15_12 : std_logic_vector(3 downto 0) is mip(15 downto 12);
    alias mip_wpri_31_16 : std_logic_vector(15 downto 0) is mip(31 downto 16);

    constant mtinst_address : natural range 0 to 255 := 16#4A#;
    constant mtinst_default : riscv32_data_type := (others => '0');
    -- mtinst is a read-only zero
    signal mtinst : riscv32_data_type := mtinst_default;

    constant mtval2_address : natural range 0 to 255 := 16#4B#;
    constant mtval2_default : riscv32_data_type := (others => '0');
    -- mtval2 is a read-only zero
    signal mtval2 : riscv32_data_type := mtval2_default;
begin

    pc_on_return <= mepc;
    mip_mtip <= '1' when m_timer_interrupt_pending else '0';
    mip_meip <= '1' when m_external_interrupt_pending else '0';

    read_handling: process(mst2slv, mscratch, mepc, mcause, mtval, mip, mtinst, mtval2)
    begin
        slv2mst.has_error <= false;
        case mst2slv.address is
            when mscratch_address =>
                slv2mst.read_data <= mscratch;
            when mepc_address =>
                slv2mst.read_data <= mepc;
            when mcause_address =>
                slv2mst.read_data <= mcause;
            when mtval_address =>
                slv2mst.read_data <= mtval;
            when mip_address =>
                slv2mst.read_data <= mip;
            when mtinst_address =>
                slv2mst.read_data <= mtinst;
            when mtval2_address =>
                slv2mst.read_data <= mtval2;
            when others =>
                slv2mst.has_error <= true;
                slv2mst.read_data <= (others => '-');
        end case;
    end process;

    mscratch_write_handling: process(clk)
    begin
        if rising_edge(clk) then
            if mst2slv.do_write and mst2slv.address = mscratch_address then
                mscratch <= mst2slv.write_data;
            end if;

            if rst then
                mscratch <= mscratch_default;
            end if;
        end if;
    end process;

    mepc_write_handling: process(clk)
    begin
        if rising_edge(clk) then
            if mst2slv.do_write and mst2slv.address = mepc_address then
                mepc <= mst2slv.write_data;
            end if;

            if interrupt_trigger then
                mepc <= interrupted_pc;
            end if;

            mepc_readonly_zero <= (others => '0');

            if rst then
                mepc <= mepc_default;
            end if;
        end if;
    end process;

    mcause_write_handling: process(clk)
    begin
        if rising_edge(clk) then
            if interrupt_trigger then
                mcause_interrupt <= '1' when interrupt_is_async else '0';
                mcause_exception_code <= std_logic_vector(to_unsigned(exception_code, mcause_exception_code'length));
            end if;

            if rst then
                mcause <= mcause_default;
            end if;
        end if;
    end process;
end architecture;
