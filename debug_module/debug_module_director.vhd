library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.bus_pkg;
use work.debug_module_pkg;
use work.debug_module_address_pkg.all;

entity debug_module_director is
    port (
        clk : in std_logic;

        bus_master_reset : in boolean;

        dmi2dm : in debug_module_pkg.debug_module_bus_mst2slv_type;
        dm2dmi : out debug_module_pkg.debug_module_bus_slv2mst_type;

        dm2bus : out bus_pkg.bus_mst2slv_type;
        bus2dm : in bus_pkg.bus_slv2mst_type;

        dm2csr : out bus_pkg.bus_mst2slv_type;
        csr2dm : in bus_pkg.bus_slv2mst_type;

        halt_hart : out boolean;
        hart_halted : in boolean;

        reset_soc : out boolean
    );
end entity;

architecture behavioural of debug_module_director is
    signal memory_bank : debug_module_pkg.debug_module_bus_data_array(16#4# to 16#7f#) := (others => (others => '0'));

    alias abstract_data_bank : debug_module_pkg.debug_module_bus_data_array(0 to 11) is memory_bank(16#4# to 16#f#);
    constant abstract_data_bank_preset : debug_module_pkg.debug_module_bus_data_array(abstract_data_bank'range) := (others => (others => '0'));

    alias dmcontrol : debug_module_pkg.debug_module_bus_data_type is memory_bank(dmcontrol_address);
    alias haltreq : std_ulogic is dmcontrol(haltreq_msb);
    alias resumereq : std_ulogic is dmcontrol(resumereq_msb);
    alias hartreset : std_ulogic is dmcontrol(hartreset_msb);
    alias ackhavereset : std_ulogic is dmcontrol(ackhavereset_msb);
    alias ackunavail : std_ulogic is dmcontrol(ackunavail_msb);
    alias hasel : std_ulogic is dmcontrol(hasel_msb);
    alias hartsello : std_ulogic_vector(hartsello_len - 1 downto 0) is dmcontrol(hartsello_msb downto hartsello_lsb);
    alias hartselhi : std_ulogic_vector(hartselhi_len - 1 downto 0) is dmcontrol(hartselhi_msb downto hartselhi_lsb);
    alias setkeepalive : std_ulogic is dmcontrol(setkeepalive_msb);
    alias clrkeepalive : std_ulogic is dmcontrol(clrkeepalive_msb);
    alias setresethaltreq : std_ulogic is dmcontrol(setresethaltreq_msb);
    alias clrresethaltreq : std_ulogic is dmcontrol(clrresethaltreq_msb);
    alias ndmreset : std_ulogic is dmcontrol(ndmreset_msb);
    alias dmactive : std_ulogic is dmcontrol(dmactive_msb);

    alias dmstatus : debug_module_pkg.debug_module_bus_data_type is memory_bank(dmstatus_address);
    alias ndmresetpending : std_ulogic is dmstatus(ndmresetpending_msb);
    alias stickyunavail : std_ulogic is dmstatus(stickyunavail_msb);
    alias impebreak : std_ulogic is dmstatus(impebreak_msb);
    alias allhavereset : std_ulogic is dmstatus(allhavereset_msb);
    alias anyhavereset : std_ulogic is dmstatus(anyhavereset_msb);
    alias allresumeack : std_ulogic is dmstatus(allresumeack_msb);
    alias anyresumeack : std_ulogic is dmstatus(anyresumeack_msb);
    alias allnonexistent : std_ulogic is dmstatus(allnonexistent_msb);
    alias anynonexistent : std_ulogic is dmstatus(anynonexistent_msb);
    alias allunavail : std_ulogic is dmstatus(allunavail_msb);
    alias anyunavail : std_ulogic is dmstatus(anyunavail_msb);
    alias allrunning : std_ulogic is dmstatus(allrunning_msb);
    alias anyrunning : std_ulogic is dmstatus(anyrunning_msb);
    alias allhalted : std_ulogic is dmstatus(allhalted_msb);
    alias anyhalted : std_ulogic is dmstatus(anyhalted_msb);
    alias authenticated : std_ulogic is dmstatus(authenticated_msb);
    alias authbusy : std_ulogic is dmstatus(authbusy_msb);
    alias hasresethaltreq : std_ulogic is dmstatus(hasresethaltreq_msb);
    alias confstrptrvalid : std_ulogic is dmstatus(confstrptrvalid_msb);
    alias version : std_ulogic_vector(version_len - 1 downto 0) is dmstatus(version_msb downto version_lsb);

    alias unimplemented_middle_bank : debug_module_pkg.debug_module_bus_data_array(0 to 35) is memory_bank(16#12# to 16#35#);
    constant unimplemented_middle_bank_preset : debug_module_pkg.debug_module_bus_data_array(unimplemented_middle_bank'range) := (others => (others => '0'));

    alias sbcs : debug_module_pkg.debug_module_bus_data_type is memory_bank(sbcs_address);
    signal sbcs_writeEvent : boolean := false;
    alias sbversion : std_ulogic_vector(sbversion_len - 1 downto 0) is sbcs(sbversion_msb downto sbversion_lsb);
    alias sbbusyerror : std_ulogic is sbcs(sbbusyerror_msb);
    alias sbbusy : std_ulogic is sbcs(sbbusy_msb);
    alias sbreadonaddr : std_ulogic is sbcs(sbreadonaddr_msb);
    alias sbaccess : std_ulogic_vector(sbaccess_len - 1 downto 0) is sbcs(sbaccess_msb downto sbaccess_lsb);
    alias sbautoincrement : std_ulogic is sbcs(sbautoincrement_msb);
    alias sbreadondata : std_ulogic is sbcs(sbreadondata_msb);
    alias sberror : std_ulogic_vector(sberror_len - 1 downto 0) is sbcs(sberror_msb downto sberror_lsb);
    alias sbasize : std_ulogic_vector(sbasize_len - 1 downto 0) is sbcs(sbasize_msb downto sbasize_lsb);
    alias sbaccess128 : std_ulogic is sbcs(sbaccess128_msb);
    alias sbaccess64 : std_ulogic is sbcs(sbaccess64_msb);
    alias sbaccess32 : std_ulogic is sbcs(sbaccess32_msb);
    alias sbaccess16 : std_ulogic is sbcs(sbaccess16_msb);
    alias sbaccess8 : std_ulogic is sbcs(sbaccess8_msb);

    alias sbaddress0 : debug_module_pkg.debug_module_bus_data_type is memory_bank(sbaddress0_address);
    signal sbaddress0_writeEvent : boolean := false;

    alias sbaddress1 : debug_module_pkg.debug_module_bus_data_type is memory_bank(sbaddress1_address);
    alias sbaddress2 : debug_module_pkg.debug_module_bus_data_type is memory_bank(sbaddress2_address);
    alias sbaddress3 : debug_module_pkg.debug_module_bus_data_type is memory_bank(sbaddress2_address);

    alias sbdata0 : debug_module_pkg.debug_module_bus_data_type is memory_bank(sbdata0_address);
    signal sbdata0_readEvent : boolean := false;
    signal sbdata0_writeEvent : boolean := false;

    alias sbdata1 : debug_module_pkg.debug_module_bus_data_type is memory_bank(sbdata1_address);
    alias sbdata2 : debug_module_pkg.debug_module_bus_data_type is memory_bank(sbdata2_address);
    alias sbdata3 : debug_module_pkg.debug_module_bus_data_type is memory_bank(sbdata3_address);

    alias unimplemented_end_bank : debug_module_pkg.debug_module_bus_data_array(0 to 63) is memory_bank(16#40# to 16#7f#);
    constant unimplemented_end_bank_preset : debug_module_pkg.debug_module_bus_data_array(unimplemented_end_bank'range) := (others => (others => '0'));

    signal systemBus_address : bus_pkg.bus_address_type;
    signal systemBus_writeData : bus_pkg.bus_data_type;
    signal systemBus_readData : bus_pkg.bus_data_type;
    signal systemBus_byteMask : bus_pkg.bus_byte_mask_type;
    signal systemBus_fault : bus_pkg.bus_fault_type;
    signal systemBus_doWrite : boolean;
    signal systemBus_doRead : boolean;
    signal systemBus_busy : boolean;
    signal systemBus_transactionComplete : boolean;

    signal systemBus_busy_latched : boolean;
    signal clear_sberror : boolean;
    signal clear_sbbusyerror : boolean;
    signal byteMaskError : boolean;
    signal busBusyError : boolean;
begin
    clear_sberror <= sbcs_writeEvent and sberror = "001";
    clear_sbbusyerror <= sbcs_writeEvent and sbbusyerror = '1';

    process(clk, systemBus_busy_latched)
        pure function translate_bus_fault (
            bus_fault : bus_pkg.bus_fault_type
        ) return std_ulogic_vector is
        begin
            case bus_fault is
                when bus_pkg.bus_fault_no_fault =>
                    return "000";
                when bus_pkg.bus_fault_address_out_of_range =>
                    return "010";
                when bus_pkg.bus_fault_unaligned_access =>
                    return "011";
                when others =>
                    return "111";
            end case;
        end function;

        pure function sbaccess_to_increment_size (
            in_var : std_ulogic_vector
        ) return unsigned is
        begin
            case in_var is
                when "000" =>
                    return to_unsigned(1, debug_module_pkg.debug_module_bus_data_type'length);
                when "001" =>
                    return to_unsigned(2, debug_module_pkg.debug_module_bus_data_type'length);
                when others =>
                    return to_unsigned(4, debug_module_pkg.debug_module_bus_data_type'length);
            end case;
        end function;


        variable address : natural;
        variable address_out_of_range : boolean := false;
        variable complete_transaction : boolean := false;
        variable prev_sberror : std_ulogic_vector(sberror_len - 1 downto 0) := (others => '0');
        variable prev_sbbusyerror : std_ulogic := '0';

        variable write_allowed : boolean := true;
    begin
        sbbusy <= '1' when systemBus_busy_latched else '0';
        write_allowed := true;
        if rising_edge(clk) then
            -- Reset all events
            sbaddress0_writeEvent <= false;
            sbcs_writeEvent <= false;
            sbdata0_readEvent <= false;
            sbdata0_writeEvent <= false;
            -- Process incoming errors
            if byteMaskError then
                prev_sberror := "100";
            end if;
            if busBusyError then
                prev_sbbusyerror := '1';
            end if;
            --systembus interaction
            if systemBus_transactionComplete then
                if sbautoincrement = '1' then
                    sbaddress0 <= std_ulogic_vector(unsigned(sbaddress0) + sbaccess_to_increment_size(sbaccess));
                end if;
                prev_sberror := translate_bus_fault(systemBus_fault);
                if prev_sberror = "000" then
                    sbdata0 <= systemBus_readData;
                end if;
            end if;

            if clear_sberror then
                prev_sberror := (others => '0');
            end if;
            if clear_sbbusyerror then
                prev_sbbusyerror := '0';
            end if;

            sberror <= prev_sberror;
            sbbusyerror <= prev_sbbusyerror;
            --regfile interaction
            if complete_transaction then
                dm2dmi.valid <= false;
                complete_transaction := false;
            elsif debug_module_pkg.debug_module_bus_requesting(dmi2dm) then
                address := to_integer(unsigned(dmi2dm.address));
                address_out_of_range := address < memory_bank'low or address > memory_bank'high;
                if address_out_of_range then
                    dm2dmi.readData <= (others => '0');
                    dm2dmi.valid <= true;
                else
                    dm2dmi.readData <= memory_bank(address);
                    if address = sbdata0_address and sberror /= "000" then
                        write_allowed := false;
                    end if;
                    if dmi2dm.writeReady and write_allowed then
                        memory_bank(address) <= dmi2dm.writeData;
                    end if;
                    dm2dmi.valid <= true;
                    complete_transaction := true;
                    -- Event handling
                    if dmi2dm.writeReady then
                        sbcs_writeEvent <= address = sbcs_address;
                        sbaddress0_writeEvent <= address = sbaddress0_address;
                        sbdata0_writeEvent <= address = sbdata0_address;
                    end if;
                    if dmi2dm.readReady then
                        sbdata0_readEvent <= address = sbdata0_address;
                    end if;
                end if;
            end if;
        end if;

        if dmactive = '0' then
            -- Reset situation
            prev_sberror := (others => '0');
            haltreq <= haltreq_reset;
            resumereq <= resumereq_reset;
            hartreset <= hartreset_reset;
            ackhavereset <= ackhavereset_reset;
            ackunavail <= ackunavail_reset;
            hasel <= hasel_reset;
            hartsello <= hartsello_reset;
            hartselhi <= hartselhi_reset;
            setkeepalive <= setkeepalive_reset;
            clrkeepalive <= clrkeepalive_reset;
            setresethaltreq <= setresethaltreq_reset;
            clrresethaltreq <= clrresethaltreq_reset;
            ndmreset <= ndmreset_reset;

            ndmresetpending <= ndmresetpending_reset;
            allhavereset <= allhavereset_reset;
            anyhavereset <= anyhavereset_reset;
            allresumeack <= allresumeack_reset;
            anyresumeack <= anyresumeack_reset;
            allnonexistent <= allnonexistent_reset;
            anynonexistent <= anynonexistent_reset;
            allunavail <= allunavail_reset;
            anyunavail <= anyunavail_reset;
            allrunning <= allrunning_reset;
            anyrunning <= anyrunning_reset;
            allhalted <= allhalted_reset;
            anyhalted <= anyhalted_reset;

            sbbusyerror <= sbbusyerror_reset;
            sbbusy <= sbbusy_reset;
            sbreadonaddr <= sbreadonaddr_reset;
            sbaccess <= sbaccess_reset;
            sbautoincrement <= sbautoincrement_reset;
            sbreadondata <= sbreadondata_reset;
            sberror <= sberror_reset;

            sbaddress0 <= sbaddress0_reset;
            sbdata0 <= sbdata0_reset;
        end if;

        -- Set ro data
        abstract_data_bank <= abstract_data_bank_preset;
        unimplemented_middle_bank <= unimplemented_middle_bank_preset;
        unimplemented_end_bank <= unimplemented_end_bank_preset;

        authenticated <= authenticated_preset;
        authbusy <= authbusy_preset;
        stickyunavail <= stickyunavail_preset;
        impebreak <= impebreak_preset;
        hasresethaltreq <= hasresethaltreq_preset;
        confstrptrvalid <= confstrptrvalid_preset;
        version <= version_preset;

        sbversion <= sbversion_preset;
        sbasize <= sbasize_preset;
        sbaccess128 <= sbaccess128_preset;
        sbaccess64 <= sbaccess64_preset;
        sbaccess32 <= sbaccess32_preset;
        sbaccess16 <= sbaccess16_preset;
        sbaccess8 <= sbaccess8_preset;
        sbaddress1 <= sbaddress1_preset;
        sbaddress2 <= sbaddress2_preset;
        sbaddress3 <= sbaddress3_preset;
        sbdata1 <= sbdata1_preset;
        sbdata2 <= sbdata2_preset;
        sbdata3 <= sbdata3_preset;
    end process;

    systemBus_busy_latcher : process(clk, systemBus_busy)
        variable systemBus_busy_latched_buf : boolean := false;
    begin
        if rising_edge(clk) then
            systemBus_busy_latched_buf := systemBus_busy;
        end if;
        systemBus_busy_latched <= systemBus_busy or systemBus_busy_latched_buf;
    end process;

    sbevent_response : process(sbaddress0_writeEvent, sbdata0_readEvent, sbdata0_writeEvent, sbaddress0, sbcs, systemBus_busy_latched)
        pure function translate_bytemask(
            in_val : std_ulogic_vector
        ) return bus_pkg.bus_byte_mask_type is
        begin
            case in_val is
                when "000" =>
                    return "0001";
                when "001" =>
                    return "0011";
                when "010" =>
                    return "1111";
                when others =>
                    return "0000";
            end case;
        end function;
        variable isReadEvent : boolean := false;
        variable isWriteEvent : boolean := false;
    begin
        systemBus_address <= (others => '-');
        systemBus_byteMask <= (others => '-');
        systemBus_writeData <= (others => '-');
        systemBus_doRead <= false;
        systemBus_doWrite <= false;
        byteMaskError <= false;
        busBusyError <= false;

        isReadEvent := sbaddress0_writeEvent and sbreadonaddr = '1';
        isReadEvent := isReadEvent or (sbdata0_readEvent and sbreadondata = '1');
        isWriteEvent := sbdata0_writeEvent;
        if isReadEvent or isWriteEvent then
            if sberror /= "000" or sbbusyerror = '1' then
                -- pass
            elsif translate_bytemask(sbaccess) = "0000" then
                byteMaskError <= true;
            elsif systemBus_busy_latched then
                busBusyError <= true;
            else
                systemBus_address <= sbaddress0;
                systemBus_byteMask <= translate_bytemask(sbaccess);
                systemBus_writeData <= sbdata0;
                systemBus_doRead <= isReadEvent;
                systemBus_doWrite <= isWriteEvent;
            end if;
        end if;
    end process;

    bus_interactor : entity work.debug_module_bus_interactor
    port map (
        clk => clk,
        reset => bus_master_reset,
        address => systemBus_address,
        write_data => systemBus_writeData,
        read_data => systemBus_readData,
        byte_mask => systemBus_byteMask,
        fault => systemBus_fault,
        do_write => systemBus_doWrite,
        do_read => systemBus_doRead,
        busy => systemBus_busy,
        transaction_complete => systemBus_transactionComplete,
        mst2slv => dm2bus,
        slv2mst => bus2dm
    );
end architecture;
