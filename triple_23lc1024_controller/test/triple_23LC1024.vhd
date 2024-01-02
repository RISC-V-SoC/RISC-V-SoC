library IEEE;
use IEEE.std_logic_1164.all;

library tb;
use tb.M23LC1024_pkg.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

entity triple_M23LC1024 is
    port (
        cs_n : in std_logic_vector(2 downto 0);
        so_sio1 : inout std_logic;
        sio2 : inout std_logic;
        hold_n_sio3 : inout std_logic;
        sck : in std_logic;
        si_sio0 : inout std_logic
    );
end triple_M23LC1024;

architecture behavioral of triple_M23LC1024 is
begin
    mem0 : entity tb.M23LC1024
    generic map (
        actor => new_actor("M23LC1024.mem0"),
        logger => get_logger("M23LC1024.mem0")
    )
    port map (
        cs_n => cs_n(0),
        so_sio1 => so_sio1,
        sio2 => sio2,
        hold_n_sio3 => hold_n_sio3,
        sck => sck,
        si_sio0 => si_sio0
    );

    mem1 : entity tb.M23LC1024
    generic map (
        actor => new_actor("M23LC1024.mem1"),
        logger => get_logger("M23LC1024.mem1")
    )
    port map (
        cs_n => cs_n(1),
        so_sio1 => so_sio1,
        sio2 => sio2,
        hold_n_sio3 => hold_n_sio3,
        sck => sck,
        si_sio0 => si_sio0
    );

    mem2 : entity tb.M23LC1024
    generic map (
        actor => new_actor("M23LC1024.mem2"),
        logger => get_logger("M23LC1024.mem2")
    )
    port map (
        cs_n => cs_n(2),
        so_sio1 => so_sio1,
        sio2 => sio2,
        hold_n_sio3 => hold_n_sio3,
        sck => sck,
        si_sio0 => si_sio0
    );
end behavioral;
