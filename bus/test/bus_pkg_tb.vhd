library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library src;
use src.bus_pkg.all;

entity bus_pkg_tb is
    generic (
        runner_cfg : string);
end entity;

architecture tb of bus_pkg_tb is
begin

    main : process
    begin
        test_runner_setup(runner, runner_cfg);
        while test_suite loop
            if run("Bus pkg sanity") then
                CHECK(bus_data_width_log2b >= bus_byte_size_log2b);
                CHECK(bus_address_type'length = 2**bus_address_width_log2b);
                CHECK(bus_data_type'length = 2**bus_data_width_log2b);
            end if;
        end loop;
        test_runner_cleanup(runner);
        wait;
    end process;
end architecture;
