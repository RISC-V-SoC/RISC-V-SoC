library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity riscv32_systemtimer is
    generic (
        clk_period : time;
        timer_period : time
    );
    port (
        clk : in std_logic;
        reset : in boolean;

        value : out unsigned(63 downto 0)
    );
end entity;

architecture behaviourial of riscv32_systemtimer is
    signal timer_done : std_logic;
begin
    process(clk)
        variable value_buf : unsigned(value'range) := (others => '0');
    begin
        if rising_edge(clk) then
            if reset then
                value_buf := (others => '0');
            elsif timer_done then
                value_buf := value_buf + 1;
            end if;
        end if;
        value <= value_buf;
    end process;

    timer : entity work.simple_multishot_timer
    generic map (
        match_val => timer_period / clk_period
    ) port map (
        clk => clk,
        rst => '0',
        done => timer_done
    );
end architecture;
