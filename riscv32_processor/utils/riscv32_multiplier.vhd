library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_multiplier is
    port (
        clk : in std_logic;
        rst : in boolean;

        inputA : in riscv32_data_type;
        inputB : in riscv32_data_type;

        outputWordHigh : in boolean;
        inputASigned : in boolean;
        inputBSigned : in boolean;

        do_operation : in boolean;
        stall : out boolean;

        output : out riscv32_data_type
    );
end entity;

architecture behaviourial of riscv32_multiplier is
    constant stage_count : natural := 3;

    signal aLow : signed(16 downto 0);
    signal bLow : signed(16 downto 0);
    signal aHigh : signed(16 downto 0);
    signal bHigh : signed(16 downto 0);

    signal mul_ll : signed(63 downto 0);
    signal mul_lh : signed(63 downto 0);
    signal mul_hl : signed(63 downto 0);
    signal mul_hh : signed(63 downto 0);


    signal multiplicationResult : std_logic_vector(63 downto 0) := (others => '0');

    type combinedInputType is record
        inputA : riscv32_data_type;
        inputASigned : boolean;
        inputB : riscv32_data_type;
        inputBSigned : boolean;
    end record;

    constant combinedInputDefault : combinedInputType := (
        inputA => (others => '0'),
        inputASigned => false,
        inputB => (others => '0'),
        inputBSigned => false
    );

    signal combinedInputCache : combinedInputType := combinedInputDefault;
    signal combinedInput : combinedInputType;

    signal stall_buf : boolean;
begin
    stall <= stall_buf;

    combinedInput.inputA <= inputA;
    combinedInput.inputASigned <= inputASigned;
    combinedInput.inputB <= inputB;
    combinedInput.inputBSigned <= inputBSigned;

    determine_stall : process(do_operation, combinedInput, combinedInputCache, outputWordHigh)
    begin
        if not do_operation then
            stall_buf <= false;
        else
            if outputWordHigh then
                stall_buf <= combinedInput /= combinedInputCache;
            else
                stall_buf <= combinedInputCache.inputA /= combinedInput.inputA or
                             combinedInputCache.inputB /= combinedInput.inputB;
            end if;
        end if;
    end process;

    stall_counter : process(clk)
        variable count : natural range 0 to stage_count := 0;
    begin
        if rising_edge(clk) then
            if rst then
                count := 0;
                combinedInputCache <= combinedInputDefault;
            else
                if stall_buf then
                    count := count + 1;
                end if;

                if count = stage_count then
                    combinedInputCache <= combinedInput;
                    count := 0;
                end if;
            end if;
        end if;
    end process;

    prepare_stage : process(clk)
    begin
        if rising_edge(clk) then
            aLow <= '0' & signed(inputA(15 downto 0));
            bLow <= '0' & signed(inputB(15 downto 0));

            aHigh(15 downto 0) <= signed(inputA(31 downto 16));
            aHigh(16) <= '1' when inputASigned and inputA(inputA'high) = '1' else '0';

            bHigh(15 downto 0) <= signed(inputB(31 downto 16));
            bHigh(16) <= '1' when inputBSigned and inputB(inputB'high) = '1' else '0';
        end if;
    end process;

    mul_stage : process(clk)
    begin
        if rising_edge(clk) then
            mul_ll <= resize(aLow * bLow, mul_ll'length);
            mul_lh <= resize(aLow * bHigh, mul_lh'length);
            mul_hl <= resize(aHigh * bLow, mul_hl'length);
            mul_hh <= resize(aHigh * bHigh, mul_hh'length);
        end if;
    end process;

    add_stage : process(clk)
        variable result_high : signed(63 downto 0);
        variable result_mid : signed(63 downto 0);
        variable result_low : signed(63 downto 0);

        variable result : signed(63 downto 0);
    begin
        if rising_edge(clk) then
            result_high := shift_left(mul_hh, 32);
            result_mid := shift_left(mul_lh + mul_hl, 16);
            result_low := mul_ll;

            result := result_high + result_mid + result_low;

            if rst then
                multiplicationResult <= (others => '0');
            elsif stall_buf then
                multiplicationResult <= std_logic_vector(result);
            end if;
        end if;
    end process;

    set_output : process(multiplicationResult, outputWordHigh)
    begin
        if outputWordHigh then
            output <= multiplicationResult(63 downto 32);
        else
            output <= multiplicationResult(31 downto 0);
        end if;
    end process;
end architecture;
