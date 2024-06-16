library ieee;
use ieee.std_logic_1164.all;

entity reset_controller is
    generic (
        master_count : natural range 1 to natural'high;
        slave_count : natural range 1 to natural'high
    );
    port (
        clk : in std_logic;
        do_reset : in boolean;
        reset_in_progress : out boolean;
        master_reset : out boolean_vector(master_count - 1 downto 0);
        slave_reset : out boolean_vector(slave_count - 1 downto 0)
    );
end entity;

architecture behavioral of reset_controller is
begin
    process(clk)
        variable master_reset_counter : natural range 0 to master_count := 0;
        variable slave_reset_counter : natural range 0 to slave_count := 0;
        variable master_reset_buf : boolean_vector(master_count - 1 downto 0) := (others => false);
        variable slave_reset_buf : boolean_vector(slave_count - 1 downto 0) := (others => false);
        variable stage_num : natural range 0 to 4 := 0;
    begin
        if rising_edge(clk) then
            if stage_num = 0 then
                if do_reset then
                    stage_num := 1;
                end if;
            elsif stage_num = 1 then
                if master_reset_counter < master_count then
                    master_reset_buf(master_reset_counter) := true;
                    master_reset_counter := master_reset_counter + 1;
                else
                    stage_num := 2;
                end if;
            elsif stage_num = 2 then
                if slave_reset_counter < slave_count then
                    slave_reset_buf(slave_reset_counter) := true;
                    slave_reset_counter := slave_reset_counter + 1;
                else
                    stage_num := 3;
                end if;
            elsif stage_num = 3 then
                if slave_reset_counter > 0 then
                    slave_reset_counter := slave_reset_counter - 1;
                    slave_reset_buf(slave_reset_counter) := false;
                else
                    stage_num := 4;
                end if;
            elsif stage_num = 4 then
                if master_reset_counter > 0 then
                    master_reset_counter := master_reset_counter - 1;
                    master_reset_buf(master_reset_counter) := false;
                else
                    stage_num := 0;
                end if;
            end if;
        end if;
        reset_in_progress <= stage_num /= 0;
        master_reset <= master_reset_buf;
        slave_reset <= slave_reset_buf;
    end process;
end architecture;
