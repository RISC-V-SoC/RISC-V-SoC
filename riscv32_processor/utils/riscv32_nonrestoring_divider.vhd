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

    constant initCycles : natural := 1;
    constant initCountStart : natural := 0;
    constant initCountEnd : natural := initCountStart + initCycles;

    constant iterationCycles : natural := riscv32_data_type'length;
    constant iterationCountStart : natural := initCountEnd;
    constant iterationCountEnd : natural := iterationCountStart + iterationCycles;

    constant postProcessCycles : natural := 1;
    constant postProcessCountStart : natural := iterationCountEnd;
    constant postProcessCountEnd : natural := postProcessCountStart + postProcessCycles;

    constant totalCycles : natural := initCycles + iterationCycles + postProcessCycles;

    signal combinedInputCache : combinedInputType := combinedInputDefault;
    signal combinedInput : combinedInputType;

    signal stall_buf : boolean;

    signal z : signed(dividend'length * 2 downto 0) := (others => '0');
    alias z_high : signed(dividend'length downto 0) is z(dividend'length * 2 downto dividend'length);
    signal dividend_signbit : std_logic;
    signal divisor_extended : signed(divisor'high + 1 downto 0);
    alias divisor_signbit : std_logic is divisor_extended(divisor'high);
    signal p : signed(output'high + 1 downto 0) := (others => '0');
    alias quotient : signed(output'range) is p(output'range);
    alias remainder : signed(output'range) is z_high(output'range);
    signal zeroRemainderFound : boolean := false;
    signal isDivisionByZero : boolean := false;
begin
    stall <= stall_buf;

    combinedInput.dividend <= dividend;
    combinedInput.divisor <= divisor;
    combinedInput.inputSigned <= is_signed;

    stall_buf <= do_operation and combinedInput /= combinedInputCache;

    stages : process(clk)
        variable z_buf : signed(z'range);
        alias z_high_buf : signed(z_high'range) is z_buf(dividend'length * 2 downto dividend'length);
        variable z_signbit : std_logic;
        variable index : natural;
        variable p_buf : signed(p'range);

        variable count : natural range 0 to totalCycles - 1 := 0;
    begin
        if rising_edge(clk) then
            -- Initial stage
            if count >= initCountStart and count < initCountEnd and stall_buf then
                zeroRemainderFound <= false;
                isDivisionByZero <= signed(divisor) = 0;
                if is_signed then
                    z <= resize(signed(dividend), z'length);
                    divisor_extended <= resize(signed(divisor), divisor_extended'length);
                    dividend_signbit <= dividend(dividend'high);
                else
                    z <= (others => '0');
                    z(dividend'range) <= signed(dividend);
                    divisor_extended <= (others => '0');
                    divisor_extended(divisor'range) <= signed(divisor);
                    dividend_signbit <= '0';
                end if;
            end if;
            -- Iterative stage
            if count >= iterationCountStart and count < iterationCountEnd then
                z_buf := z;
                index := p'high - (count - iterationCountStart);

                if z_buf = 0 then
                    zeroRemainderFound <= true;
                end if;

                z_signbit := z_high_buf(z_high_buf'high);
                z_buf := shift_left(z_buf, 1);
                if z_signbit = divisor_signbit then
                    p(index) <= '1';
                    z_high_buf := z_high_buf - divisor_extended;
                else
                    p(index) <= '0';
                    z_high_buf := z_high_buf + divisor_extended;
                end if;

                z <= z_buf;
            end if;
            -- Finalization stage
            if count >= postProcessCountStart and count < postProcessCountEnd then
                p_buf := p;

                p_buf(p_buf'high) := not p_buf(p_buf'high);
                p_buf(0) := '1';

                if isDivisionByZero then
                    z_high(dividend'range) <= signed(dividend);
                    p_buf := (others => '1');
                elsif (dividend_signbit /= z_high(z_high'high) and z /= 0) or zeroRemainderFound then
                    if z_high(z_high'high) = divisor_signbit then
                        z_high <= z_high - divisor_extended;
                        p_buf := p_buf + 1;
                    else
                        z_high <= z_high + divisor_extended;
                        p_buf := p_buf - 1;
                    end if;
                end if;

                p <= p_buf;
                combinedInputCache.dividend <= dividend;
                combinedInputCache.divisor <= divisor;
                combinedInputCache.inputSigned <= is_signed;
                count := 0;
            elsif stall_buf then
                count := count + 1;
            end if;

            if rst then
                p <= (others => '0');
                z <= (others => '0');
                combinedInputCache <= combinedInputDefault;
                count := 0;
            end if;

        end if;
    end process;

    determine_output : process(output_rem, quotient, remainder)
    begin
        if output_rem then
            output <= std_logic_vector(remainder);
        else
            output <= std_logic_vector(quotient);
        end if;
    end process;
end architecture;
