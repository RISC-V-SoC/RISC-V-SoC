library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

package riscv32_fp32_pkg is
    type resultType is record
        result : riscv32_data_type;
        err_flags : riscv32_f32_exception_flags;
    end record;

    constant resultType_default : resultType := (
        result => (others => '0'),
        err_flags => riscv32_f32_exception_flags_default
    );

    type resultType_arr is array (natural range <>) of resultType;

    -- 2 bits before the mantissa represent 2**0 and 2**1
    constant premantissa_length : natural := 2;
    -- Per the binary32 spec
    constant mantissa_length : natural := 23;
    -- Two bits, guard and round
    constant postmantissa_length : natural := 2;

    constant fraction_high : natural := premantissa_length + mantissa_length + postmantissa_length - 1;
    constant fraction_low : natural := 0;
    constant premantissa_high : natural := fraction_high;
    constant premantissa_low : natural := premantissa_high - premantissa_length + 1;
    constant mantissa_high : natural := premantissa_low - 1;
    constant mantissa_low : natural := mantissa_high - mantissa_length + 1;
    constant postmantissa_high : natural := mantissa_low - 1;
    constant postmantissa_low : natural := 0;
    constant guard_index : natural := postmantissa_high;
    constant round_index : natural := guard_index - 1;

    -- High represents 2**1, high-1 2**0, etc
    subtype fraction_type is unsigned(fraction_high downto fraction_low);

    type expanded_float_type is record
        is_negative : boolean;
        exponent : signed(8 downto 0);
        fraction : fraction_type;
        sticky : boolean;
    end record;

    constant expanded_float_default : expanded_float_type := (
        is_negative => false,
        exponent => (others => '0'),
        fraction => (others => '0'),
        sticky => false
    );

    pure function to_binary32 (
        input : expanded_float_type;
        rounding_mode : riscv32_f32_rounding_mode
    ) return resultType;

    pure function unsigned_to_float (
        input : riscv32_data_type;
        rounding_mode : riscv32_f32_rounding_mode
    ) return resultType;

    pure function signed_to_float (
        input : riscv32_data_type;
        rounding_mode : riscv32_f32_rounding_mode
    ) return resultType;

end package;

package body riscv32_fp32_pkg is

    pure function normalize (
        input : expanded_float_type
    ) return expanded_float_type is
        variable ret : expanded_float_type;
        variable premantissa : unsigned(premantissa_length - 1 downto 0);
    begin
        ret := input;
        premantissa := input.fraction(premantissa_high downto premantissa_low);
        if premantissa > 1 then
            ret.exponent := ret.exponent + to_signed(to_integer(premantissa - 1), ret.exponent'length);
            ret.fraction(premantissa_high downto premantissa_low) := to_unsigned(1, premantissa_length);
        end if;
        return ret;
    end function;

    pure function round_fraction (
        input : expanded_float_type;
        rounding_mode : riscv32_f32_rounding_mode
    ) return expanded_float_type is
        variable ret : expanded_float_type;
        variable postmantissa : unsigned(postmantissa_length - 1 downto 0);
        variable fraction_without_post : unsigned(fraction_high downto mantissa_low);
        variable guard : boolean;
        variable round : boolean;
        variable sticky : boolean;
        variable mantissa_lsb : boolean;
    begin
        postmantissa := input.fraction(postmantissa_high downto postmantissa_low);
        fraction_without_post := input.fraction(fraction_without_post'range);
        guard := input.fraction(guard_index) = '1';
        round := input.fraction(round_index) = '1';
        sticky := input.sticky;
        mantissa_lsb := input.fraction(mantissa_low) = '1';
        case rounding_mode is
            when f32_rounding_rup =>
                if (postmantissa > 0 or input.sticky) and not input.is_negative then
                    fraction_without_post := fraction_without_post + 1;
                end if;
            when f32_rounding_rdn =>
                if (postmantissa > 0 or input.sticky) and input.is_negative then
                    fraction_without_post := fraction_without_post + 1;
                end if;
            when f32_rounding_rne =>
                if guard and not round and not sticky then
                    if mantissa_lsb then
                        fraction_without_post := fraction_without_post + 1;
                    end if;
                elsif guard then
                    fraction_without_post := fraction_without_post + 1;
                end if;
            when others =>
        end case;
        ret := input;
        ret.fraction := (others => '0');
        ret.fraction(fraction_without_post'range) := fraction_without_post;
        return normalize(ret);
    end function;

    pure function to_binary32 (
        input : expanded_float_type;
        rounding_mode : riscv32_f32_rounding_mode
    ) return resultType is
        variable input_modified : expanded_float_type;
        variable ret : resultType := resultType_default;
        variable modified_exponent : signed(input.exponent'range);
        variable modified_fraction : unsigned(input.fraction'range);
        variable postmantissa : unsigned(postmantissa_length - 1 downto 0);
    begin

        postmantissa := input.fraction(postmantissa_high downto postmantissa_low);
        if postmantissa /= 0 or input.sticky then
            ret.err_flags.inexact := true;
        end if;
        ret.result(31) := '1' when input.is_negative else '0';
        input_modified := round_fraction(input, rounding_mode);
        ret.result(22 downto 0) := std_logic_vector(input_modified.fraction(mantissa_high downto mantissa_low));

        modified_exponent := input_modified.exponent + to_signed(126, modified_exponent'length);
        ret.result(30 downto 23) := std_logic_vector(modified_exponent(modified_exponent'high - 1 downto modified_exponent'high - 1 - 7));
        return ret;
    end function;

    pure function unsigned_to_float (
        input : riscv32_data_type
    ) return expanded_float_type is
        variable expanded_float : expanded_float_type := expanded_float_default;
        variable ret : resultType := resultType_default;
        variable firstOneIndex : natural := 0;
        variable input_processed : unsigned(input'range);
    begin
        for i in input'high downto 0 loop
            if input(i) = '1' then
                firstOneIndex := i;
                exit;
            end if;
        end loop;
        expanded_float.exponent := to_signed(firstOneIndex + 1, expanded_float.exponent'length);
        input_processed := shift_left(unsigned(input), input'high - firstOneIndex);
        expanded_float.fraction(fraction_high - 1 downto fraction_low) := input_processed(input'high downto input'high - fraction_high + 1);
        expanded_float.sticky := input_processed(input'high - fraction_high - 1 downto 0) /= 0;
        return expanded_float;
    end function;

    pure function unsigned_to_float (
        input : riscv32_data_type;
        rounding_mode : riscv32_f32_rounding_mode
    ) return resultType is
    begin
        return to_binary32(unsigned_to_float(input), rounding_mode);
    end function;

    pure function signed_to_float (
        input : riscv32_data_type;
        rounding_mode : riscv32_f32_rounding_mode
    ) return resultType is
        variable abs_input : riscv32_data_type;
        variable result : expanded_float_type;
    begin
        if signed(input) < 0 then
            abs_input := riscv32_data_type(unsigned(not input) + 1);
            result := unsigned_to_float(abs_input);
            result.is_negative := true;
        else
            result := unsigned_to_float(input);
        end if;
        return to_binary32(result, rounding_mode);
    end function;

end package body;
