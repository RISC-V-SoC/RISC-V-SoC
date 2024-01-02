library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity generic_fifo is
    generic (
        depth_log2b : natural range 3 to natural'high := 4;
        word_size_log2b : natural range 1 to natural'high := 3
    );
    port (
        clk : in std_logic;
        reset : in boolean;
        empty : out boolean;
        almost_empty : out boolean;
        underflow : out boolean;
        full : out boolean;
        almost_full : out boolean;
        overflow : out boolean;
        count : out natural range 0 to 2**depth_log2b;

        data_in : in std_logic_vector(2**word_size_log2b - 1 downto 0);
        push_data : in boolean;

        data_out : out std_logic_vector(2**word_size_log2b - 1 downto 0);
        pop_data : in boolean
    );
end entity;

architecture behavioral of generic_fifo is
    constant depth : natural := 2**depth_log2b;
    constant word_size : natural := 2**word_size_log2b;
    type memory_type is array (natural range 0 to 2**depth_log2b - 1) of std_logic_vector(word_size - 1 downto 0);

    signal mem : memory_type;

begin
    process(clk)
        variable read_pointer : unsigned(depth_log2b - 1 downto 0) := (others => '0');
        variable write_pointer : unsigned(depth_log2b - 1 downto 0) := (others => '0');
        variable count_buf : natural range 0 to 2**depth_log2b := 0;
        variable full_buf : boolean := false;
        variable empty_buf : boolean := true;
        variable almost_empty_buf : boolean := true;
    begin
        if rising_edge(clk) then
            overflow <= false;
            underflow <= false;
            if reset then
                read_pointer := (others => '0');
                write_pointer := (others => '0');
                count_buf := 0;
                empty_buf := true;
            else
                empty_buf := count_buf = 0;
                if push_data then 
                    if not full_buf then
                        mem(to_integer(write_pointer)) <= data_in;
                        write_pointer := write_pointer + 1;
                    else
                        overflow <= true;
                    end if;
                end if;

                if pop_data then
                    if not empty_buf then
                        read_pointer := read_pointer + 1;
                        empty_buf := count_buf = 1;
                    else
                        underflow <= true;
                    end if;
                end if;

                if push_data and not pop_data and count_buf /= 2**depth_log2b then
                    count_buf := count_buf + 1;
                elsif pop_data and not push_data and count_buf /= 0 then
                    count_buf := count_buf - 1;
                end if;
            end if;


            full_buf := count_buf = 2**depth_log2b;
            almost_full <= count_buf >= 2**depth_log2b - 1;
            almost_empty_buf := count_buf <= 1;
            data_out <= mem(to_integer(read_pointer));
        end if;
        count <= count_buf;
        full <= full_buf;
        empty <= empty_buf;
        almost_empty <= almost_empty_buf;
    end process;


end architecture;
