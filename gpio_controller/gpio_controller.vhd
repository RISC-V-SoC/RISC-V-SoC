library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.bus_pkg;

entity gpio_controller is
    generic (
        gpio_count : natural range 1 to natural'high
    );
    port (
        clk : in std_logic;
        reset : in boolean;
        gpio : inout std_logic_vector(gpio_count - 1 downto 0);

        mst2slv : in bus_pkg.bus_mst2slv_type;
        slv2mst : out bus_pkg.bus_slv2mst_type
    );
end entity;

architecture behavioral of gpio_controller is
    type inout_type is (
        INPUT,
        OUTPUT);
    subtype inout_type_enum_index is natural range 0 to inout_type'pos(inout_type'high);
    type inout_type_array is array (natural range <>) of inout_type;
    constant inout_type_bitlength : natural := integer(ceil(log2(real(inout_type'pos(inout_type'high)))));

    constant bytes_required : natural := gpio_count;
    constant config_base_address : natural := 0;
    constant config_high_address : natural := config_base_address + bytes_required - 1;

    constant data_base_address : natural := config_high_address + 1;
    constant data_high_address : natural := data_base_address + bytes_required - 1;

    signal slv2mst_buf : bus_pkg.bus_slv2mst_type := bus_pkg.BUS_SLV2MST_IDLE;
    signal inout_array : inout_type_array(gpio_count - 1 downto 0) := (others => INPUT);
    signal inout_byte_array : bus_pkg.bus_byte_array(0 to bytes_required - 1) := (others => (others => '0'));
    signal data_out_array : std_logic_vector(gpio_count - 1 downto 0) := (others => '0');
    signal data_in_array : std_logic_vector(gpio_count - 1 downto 0) := (others => '0');
begin
    slv2mst <= slv2mst_buf;

    bus_handling : process(clk)
        variable slv2mst_tmp : bus_pkg.bus_slv2mst_type := bus_pkg.BUS_SLV2MST_IDLE;
        variable address : unsigned(mst2slv.address'range);
        variable byte_in : std_logic_vector(7 downto 0);
        variable byte_out : std_logic_vector(7 downto 0);
    begin
        if rising_edge(clk) then
            if reset then
                slv2mst_buf <= bus_pkg.BUS_SLV2MST_IDLE;
                slv2mst_tmp := bus_pkg.BUS_SLV2MST_IDLE;
                inout_byte_array <= (others => (others => '0'));
                data_out_array <= (others => '0');
            elsif bus_pkg.any_transaction(mst2slv, slv2mst_buf) then
                slv2mst_buf <= bus_pkg.BUS_SLV2MST_IDLE;
                slv2mst_tmp := bus_pkg.BUS_SLV2MST_IDLE;
            elsif slv2mst_tmp.valid then
                slv2mst_buf <= slv2mst_tmp;
            elsif bus_pkg.bus_requesting(mst2slv) then
                address := unsigned(mst2slv.address);
                for index in 0 to bus_pkg.bus_bytes_per_word - 1 loop

                    byte_in := mst2slv.writeData(index*8 + 7 downto index*8);

                    if mst2slv.byteMask(index) = '0' then
                        next;
                    end if;

                    if address + index >= config_base_address and address + index <= config_high_address then
                        if mst2slv.writeReady = '1' then
                            inout_byte_array(to_integer(address) + index) <= byte_in;
                        end if;
                        byte_out := inout_byte_array(to_integer(address) + index);
                    end if;

                    if address + index >= data_base_address and address + index <= data_high_address then
                        if mst2slv.writeReady = '1' then
                            data_out_array(to_integer(address) + index - data_base_address) <= byte_in(0);
                        end if;
                        byte_out(0) := data_in_array(to_integer(address) + index - data_base_address);
                    end if;

                    slv2mst_tmp.readData((index + 1) * bus_pkg.bus_byte_size - 1 downto index*bus_pkg.bus_byte_size) := byte_out;
                end loop;
                slv2mst_tmp.valid := true;
            end if;
        end if;
    end process;

    config_translation : process(inout_byte_array)
        variable numeric_value : natural;
    begin
        for index in 0 to gpio_count - 1 loop
            numeric_value := to_integer(unsigned(inout_byte_array(index)));
            if numeric_value > inout_type'pos(inout_type'high) then
                inout_array(index) <= INPUT;
            else
                inout_array(index) <= inout_type'val(numeric_value);
            end if;
        end loop;
    end process;

    set_output : process(inout_array, data_out_array)
    begin
        for index in 0 to gpio_count - 1 loop
            case inout_array(index) is
                when INPUT =>
                    gpio(index) <= 'Z';
                when OUTPUT =>
                    gpio(index) <= data_out_array(index);
            end case;
        end loop;
    end process;

    set_input : process(inout_array, gpio)
    begin
        for index in 0 to gpio_count - 1 loop
            case inout_array(index) is
                when INPUT =>
                    data_in_array(index) <= gpio(index);
                when OUTPUT =>
                    data_in_array(index) <= '0';
            end case;
        end loop;
    end process;
end architecture;
