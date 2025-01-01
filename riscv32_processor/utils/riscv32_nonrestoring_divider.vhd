library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_nonrestoring_divider is
    port (
        clk : in std_logic;
        rst : in boolean;

        dividend : in riscv32_data_type;
        divisor : in riscv32_data_type;

        is_signed : in boolean;
        output_rem : in boolean;

        do_operation : in boolean;
        stall : out boolean;

        output : out riscv32_data_type
    );
end entity;

architecture behaviourial of riscv32_nonrestoring_divider is
    type combinedInputType is record
        dividend : riscv32_data_type;
        divisor : riscv32_data_type;
        inputSigned : boolean;
    end record;

    constant combinedInputDefault : combinedInputType := (
        dividend => (others => '0'),
        divisor => std_logic_vector(to_unsigned(1, divisor'length)),
        inputSigned => false
    );

    signal combinedInputCache : combinedInputType := combinedInputDefault;
    signal combinedInput : combinedInputType;

    signal stall_buf : boolean;

    signal z_buf : signed(dividend'length * 2 downto 0);
    signal quotient_buf : signed(riscv32_data_type'range);
    signal p_buf : signed(quotient_buf'high + 1 downto 0);
    signal s_buf : signed(output'range);

    signal z_signbit_buf : std_logic;
    signal dividend_signbit_buf : std_logic;
    signal divisor_extended_buf : signed(divisor'high + 1 downto 0);


begin
    --stall <= stall_buf and false;

    combinedInput.dividend <= dividend;
    combinedInput.divisor <= divisor;
    combinedInput.inputSigned <= is_signed;

    stall_buf <= do_operation and combinedInput /= combinedInputCache;

    do_division : process
        variable z : signed(dividend'length * 2 downto 0);
        alias z_high : signed(dividend'length downto 0) is z(dividend'length * 2 downto dividend'length);
        variable z_signbit : std_logic;

        variable dividend_signbit : std_logic;

        variable divisor_extended : signed(divisor'high + 1 downto 0);
        alias divisor_signbit : std_logic is divisor_extended(divisor'high);

        variable do_postincrement_quotient : boolean := false;

        variable quotient : signed(riscv32_data_type'range) := (others => '0');
        variable p : signed(quotient'high + 1 downto 0);
        variable remainder : signed(riscv32_data_type'range) := (others => '0');

        variable zeroRemainderFound : boolean := false;
        variable isDivisionByZero : boolean := false;
    begin
        stall <= true;
        wait until rising_edge(clk) and do_operation;
        -- initial stage
        zeroRemainderFound := false;
        isDivisionByZero := signed(divisor) = 0;
        if not is_signed then
            z := (others => '0');
            z(dividend'range) := signed(dividend);
            divisor_extended := (others => '0');
            divisor_extended(divisor'range) := signed(divisor);
            dividend_signbit := '0';
        else
            z := resize(signed(dividend), z'length);
            divisor_extended := resize(signed(divisor), divisor_extended'length);
            dividend_signbit := dividend(dividend'high);
        end if;

        divisor_extended_buf <= divisor_extended;
        z_buf <= z;
        quotient_buf <= quotient;
        p_buf <= p;
        s_buf <= z(z'high -1 downto 32);
        z_signbit_buf <= z_signbit;
        dividend_signbit_buf <= dividend_signbit;

        wait until rising_edge(clk);

        -- iterative stage
        for i in dividend'length -1 downto 0 loop
            if z = 0 then
                zeroRemainderFound := true;
            end if;
            z_signbit := z_high(z_high'high);
            z := shift_left(z, 1);
            z_buf <= z;
            quotient_buf <= quotient;
            p_buf <= p;
            s_buf <= z(z'high -1 downto 32);
            z_signbit_buf <= z_signbit;
            dividend_signbit_buf <= dividend_signbit;
            wait until rising_edge(clk);

            if z_signbit = divisor_signbit then
                p(i+1) := '1';
                z_high := z_high - divisor_extended;
            else
                p(i+1) := '0';
                z_high := z_high + divisor_extended;
            end if;
            z_buf <= z;
            quotient_buf <= quotient;
            p_buf <= p;
            s_buf <= z(z'high -1 downto 32);
            z_signbit_buf <= z_signbit;
            dividend_signbit_buf <= dividend_signbit;
            wait until rising_edge(clk);
        end loop;

        -- Post-process quotient
        p(p'high) := not p(p'high);
        p(0) := '1';
        z_buf <= z;
        quotient_buf <= quotient;
        p_buf <= p;
        s_buf <= z(z'high -1 downto 32);
        z_signbit_buf <= z_signbit;
        dividend_signbit_buf <= dividend_signbit;
        wait until rising_edge(clk);
        z_buf <= z;
        quotient_buf <= quotient;
        p_buf <= p;
        s_buf <= z(z'high -1 downto 32);
        z_signbit_buf <= z_signbit;
        dividend_signbit_buf <= dividend_signbit;
        wait until rising_edge(clk);

        -- Correction stage
        if isDivisionByZero then
            z_high(dividend'range) := signed(dividend);
            p := (others => '1');
        elsif (dividend_signbit /= z_high(z_high'high) and z /= 0) or zeroRemainderFound then
            if z_high(z_high'high) = divisor_signbit then
                z_high := z_high - divisor_extended;
                p := p + 1;
            else
                z_high := z_high + divisor_extended;
                p := p - 1;
            end if;
        end if;
        quotient := p(quotient'range);
        z_buf <= z;
        quotient_buf <= quotient;
        p_buf <= p;
        s_buf <= z(z'high -1 downto 32);
        z_signbit_buf <= z_signbit;
        dividend_signbit_buf <= dividend_signbit;
        wait until rising_edge(clk);

        -- set remainder
        remainder := z_high(remainder'range);

        if output_rem then
            output <= std_logic_vector(remainder);
        else
            output <= std_logic_vector(quotient);
        end if;
        z_buf <= z;
        quotient_buf <= quotient;
        p_buf <= p;
        s_buf <= z(z'high -1 downto 32);
        z_signbit_buf <= z_signbit;
        dividend_signbit_buf <= dividend_signbit;
        stall <= false;
        wait until rising_edge(clk);
    end process;

end architecture;
