library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package debug_module_address_pkg is

    ---------------------------------------------------------------------------
    -- DMCONTROL (0x10)
    ---------------------------------------------------------------------------
    constant dmcontrol_address : natural := 16#10#;

    constant haltreq_msb : natural := 31;
    constant haltreq_lsb : natural := 31;
    constant haltreq_reset : std_ulogic := '0';

    constant resumereq_msb : natural := 30;
    constant resumereq_lsb : natural := 30;
    constant resumereq_reset : std_ulogic := '0';

    constant hartreset_msb : natural := 29;
    constant hartreset_lsb : natural := 29;
    constant hartreset_reset : std_ulogic := '0';

    constant ackhavereset_msb : natural := 28;
    constant ackhavereset_lsb : natural := 28;
    constant ackhavereset_reset : std_ulogic := '0';

    constant ackunavail_msb : natural := 27;
    constant ackunavail_lsb : natural := 27;
    constant ackunavail_reset : std_ulogic := '0';

    constant hasel_msb : natural := 26;
    constant hasel_lsb : natural := 26;
    constant hasel_reset : std_ulogic := '0';

    constant hartsello_msb : natural := 25;
    constant hartsello_lsb : natural := 16;
    constant hartsello_len : natural := hartsello_msb - hartsello_lsb + 1;
    constant hartsello_reset : std_ulogic_vector(
        hartsello_msb downto hartsello_lsb
    ) := (others => '0');

    constant hartselhi_msb : natural := 15;
    constant hartselhi_lsb : natural := 6;
    constant hartselhi_len : natural := hartselhi_msb - hartselhi_lsb + 1;
    constant hartselhi_reset : std_ulogic_vector(
        hartselhi_msb downto hartselhi_lsb
    ) := (others => '0');

    constant setkeepalive_msb : natural := 5;
    constant setkeepalive_lsb : natural := 5;
    constant setkeepalive_reset : std_ulogic := '0';

    constant clrkeepalive_msb : natural := 4;
    constant clrkeepalive_lsb : natural := 4;
    constant clrkeepalive_reset : std_ulogic := '0';

    constant setresethaltreq_msb : natural := 3;
    constant setresethaltreq_lsb : natural := 3;
    constant setresethaltreq_reset : std_ulogic := '0';

    constant clrresethaltreq_msb : natural := 2;
    constant clrresethaltreq_lsb : natural := 2;
    constant clrresethaltreq_reset : std_ulogic := '0';

    constant ndmreset_msb : natural := 1;
    constant ndmreset_lsb : natural := 1;
    constant ndmreset_reset : std_ulogic := '0';

    constant dmactive_msb : natural := 0;
    constant dmactive_lsb : natural := 0;
    ---------------------------------------------------------------------------
    -- DMSTATUS (0x11)
    ---------------------------------------------------------------------------
    constant dmstatus_address : natural := 16#11#;

    constant ndmresetpending_msb : natural := 24;
    constant ndmresetpending_lsb : natural := 24;
    constant ndmresetpending_reset : std_ulogic := '0';

    constant stickyunavail_msb : natural := 23;
    constant stickyunavail_lsb : natural := 23;
    constant stickyunavail_preset : std_ulogic := '0';

    constant impebreak_msb : natural := 22;
    constant impebreak_lsb : natural := 22;
    constant impebreak_preset : std_ulogic := '0';

    constant allhavereset_msb : natural := 19;
    constant allhavereset_lsb : natural := 19;
    constant allhavereset_reset : std_ulogic := '0';

    constant anyhavereset_msb : natural := 18;
    constant anyhavereset_lsb : natural := 18;
    constant anyhavereset_reset : std_ulogic := '0';

    constant allresumeack_msb : natural := 17;
    constant allresumeack_lsb : natural := 17;
    constant allresumeack_reset : std_ulogic := '0';

    constant anyresumeack_msb : natural := 16;
    constant anyresumeack_lsb : natural := 16;
    constant anyresumeack_reset : std_ulogic := '0';

    constant allnonexistent_msb : natural := 15;
    constant allnonexistent_lsb : natural := 15;
    constant allnonexistent_reset : std_ulogic := '0';

    constant anynonexistent_msb : natural := 14;
    constant anynonexistent_lsb : natural := 14;
    constant anynonexistent_reset : std_ulogic := '0';

    constant allunavail_msb : natural := 13;
    constant allunavail_lsb : natural := 13;
    constant allunavail_reset : std_ulogic := '0';

    constant anyunavail_msb : natural := 12;
    constant anyunavail_lsb : natural := 12;
    constant anyunavail_reset : std_ulogic := '0';

    constant allrunning_msb : natural := 11;
    constant allrunning_lsb : natural := 11;
    constant allrunning_reset : std_ulogic := '0';

    constant anyrunning_msb : natural := 10;
    constant anyrunning_lsb : natural := 10;
    constant anyrunning_reset : std_ulogic := '0';

    constant allhalted_msb : natural := 9;
    constant allhalted_lsb : natural := 9;
    constant allhalted_reset : std_ulogic := '0';

    constant anyhalted_msb : natural := 8;
    constant anyhalted_lsb : natural := 8;
    constant anyhalted_reset : std_ulogic := '0';

    constant authenticated_msb : natural := 7;
    constant authenticated_lsb : natural := 7;
    constant authenticated_preset : std_ulogic := '0';

    constant authbusy_msb : natural := 6;
    constant authbusy_lsb : natural := 6;
    constant authbusy_preset : std_ulogic := '0';

    constant hasresethaltreq_msb : natural := 5;
    constant hasresethaltreq_lsb : natural := 5;
    constant hasresethaltreq_preset : std_ulogic := '0';

    constant confstrptrvalid_msb : natural := 4;
    constant confstrptrvalid_lsb : natural := 4;
    constant confstrptrvalid_preset : std_ulogic := '0';

    constant version_msb : natural := 3;
    constant version_lsb : natural := 0;
    constant version_len : natural := 4;
    constant version_preset : std_ulogic_vector(
        version_msb downto version_lsb
    ) := std_ulogic_vector(to_unsigned(3, version_len));

    ---------------------------------------------------------------------------
    -- SBCS (0x38)
    ---------------------------------------------------------------------------
    constant sbcs_address : natural := 16#38#;

    constant sbversion_msb : natural := 31;
    constant sbversion_lsb : natural := 29;
    constant sbversion_len : natural := sbversion_msb - sbversion_lsb + 1;
    constant sbversion_preset : std_ulogic_vector(
        sbversion_msb downto sbversion_lsb
    ) := std_ulogic_vector(to_unsigned(1, sbversion_len));

    constant sbbusyerror_msb : natural := 22;
    constant sbbusyerror_lsb : natural := 22;
    constant sbbusyerror_reset : std_ulogic := '0';

    constant sbbusy_msb : natural := 21;
    constant sbbusy_lsb : natural := 21;
    constant sbbusy_reset : std_ulogic := '0';

    constant sbreadonaddr_msb : natural := 20;
    constant sbreadonaddr_lsb : natural := 20;
    constant sbreadonaddr_reset : std_ulogic := '0';

    constant sbaccess_msb : natural := 19;
    constant sbaccess_lsb : natural := 17;
    constant sbaccess_len : natural := sbaccess_msb - sbaccess_lsb + 1;
    constant sbaccess_reset : std_ulogic_vector(
        sbaccess_msb downto sbaccess_lsb
    ) := std_ulogic_vector(to_unsigned(2, sbaccess_len));

    constant sbautoincrement_msb : natural := 16;
    constant sbautoincrement_lsb : natural := 16;
    constant sbautoincrement_reset : std_ulogic := '0';

    constant sbreadondata_msb : natural := 15;
    constant sbreadondata_lsb : natural := 15;
    constant sbreadondata_reset : std_ulogic := '0';

    constant sberror_msb : natural := 14;
    constant sberror_lsb : natural := 12;
    constant sberror_len : natural := sberror_msb - sberror_lsb + 1;
    constant sberror_reset : std_ulogic_vector(
        sberror_msb downto sberror_lsb
    ) := (others => '0');

    constant sbasize_msb : natural := 11;
    constant sbasize_lsb : natural := 5;
    constant sbasize_len : natural := sbasize_msb - sbasize_lsb + 1;
    constant sbasize_preset : std_ulogic_vector(
        sbasize_msb downto sbasize_lsb
    ) := std_ulogic_vector(to_unsigned(32, sbasize_len));

    constant sbaccess128_msb : natural := 4;
    constant sbaccess128_lsb : natural := 4;
    constant sbaccess128_preset : std_ulogic := '0';

    constant sbaccess64_msb : natural := 3;
    constant sbaccess64_lsb : natural := 3;
    constant sbaccess64_preset : std_ulogic := '0';

    constant sbaccess32_msb : natural := 2;
    constant sbaccess32_lsb : natural := 2;
    constant sbaccess32_preset : std_ulogic := '1';

    constant sbaccess16_msb : natural := 1;
    constant sbaccess16_lsb : natural := 1;
    constant sbaccess16_preset : std_ulogic := '1';

    constant sbaccess8_msb : natural := 0;
    constant sbaccess8_lsb : natural := 0;
    constant sbaccess8_preset : std_ulogic := '1';

    ---------------------------------------------------------------------------
    -- SBADDRESS0 (0x39)
    ---------------------------------------------------------------------------
    constant sbaddress0_address : natural := 16#39#;
    constant sbaddress0_reset : std_ulogic_vector(31 downto 0) :=
        (others => '0');

    ---------------------------------------------------------------------------
    -- SBADDRESS1 (0x3A), SBADDRESS2 (0x3B), SBADDRESS3 (0x37)
    ---------------------------------------------------------------------------
    constant sbaddress1_address : natural := 16#3a#;
    constant sbaddress1_preset : std_ulogic_vector(31 downto 0) :=
        (others => '0');
    constant sbaddress2_address : natural := 16#3b#;
    constant sbaddress2_preset : std_ulogic_vector(31 downto 0) :=
        (others => '0');
    constant sbaddress3_address : natural := 16#37#;
    constant sbaddress3_preset : std_ulogic_vector(31 downto 0) :=
        (others => '0');


    ---------------------------------------------------------------------------
    -- SBDATA0 (0x3C)
    ---------------------------------------------------------------------------
    constant sbdata0_address : natural := 16#3c#;
    constant sbdata0_reset : std_ulogic_vector(31 downto 0) :=
        (others => '0');

    ---------------------------------------------------------------------------
    -- SBDATA1 (0x3D), SBDATA2 (0x3E), SBDATA3 (0x3F)
    ---------------------------------------------------------------------------
    constant sbdata1_address : natural := 16#3d#;
    constant sbdata1_preset : std_ulogic_vector(31 downto 0) :=
        (others => '0');
    constant sbdata2_address : natural := 16#3e#;
    constant sbdata2_preset : std_ulogic_vector(31 downto 0) :=
        (others => '0');
    constant sbdata3_address : natural := 16#3f#;
    constant sbdata3_preset : std_ulogic_vector(31 downto 0) :=
        (others => '0');

end package debug_module_address_pkg;
