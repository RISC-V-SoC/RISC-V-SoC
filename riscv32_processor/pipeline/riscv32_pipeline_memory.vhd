library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_pipeline_memory is
    port (
        -- From execute stage: control signals
        memoryControlWord : in riscv32_MemoryControlWord_type;

        -- From execute stage: data
        requestAddress : in riscv32_data_type;
        rs1Data : in riscv32_data_type;
        rs2Data : in riscv32_data_type;
        uimmidiate : in riscv32_data_type;

        -- To writeback stage: data
        memDataRead: out riscv32_data_type;

        -- To/from mem2bus unit
        doMemRead : out boolean;
        doMemWrite : out boolean;
        memAddress : out riscv32_address_type;
        memByteMask : out riscv32_byte_mask_type;
        dataToMem : out riscv32_data_type;
        dataFromMem : in riscv32_data_type;
        faultFromMem : in boolean;

        -- To/from control and status registers
        csrOut : out riscv32_to_csr_type;
        csr_in : in riscv32_from_csr_type;

        -- Exception data
        exception_type : out riscv32_pipeline_exception_type;
        exception_code : out riscv32_exception_code_type
    );
end entity;

architecture behaviourial of riscv32_pipeline_memory is
    signal addressToMem : riscv32_address_type;
    signal byteMaskToMem : riscv32_byte_mask_type;
    signal memWriteData : riscv32_data_type;

    signal address_misaligned : boolean;
begin

    exception_handling : process(csr_in, memoryControlWord, address_misaligned, faultFromMem)
    begin
        if memoryControlWord.csrOp and csr_in.error then
            exception_type <= exception_sync;
        elsif memoryControlWord.MemOp and address_misaligned then
            exception_type <= exception_sync;
        elsif memoryControlWord.MemOp and faultFromMem then
            exception_type <= exception_sync;
        else
            exception_type <= exception_none;
        end if;
    end process;

    exception_code_handling : process(memoryControlWord, address_misaligned, faultFromMem)
    begin
        exception_code <= 0;
        if memoryControlWord.csrOp then
            exception_code <= riscv32_exception_code_illegal_instruction;
        elsif memoryControlWord.MemOp and address_misaligned then
            if not memoryControlWord.MemOpIsWrite then
                exception_code <= riscv32_exception_code_load_address_misaligned;
            else
                exception_code <= riscv32_exception_code_store_address_misaligned;
            end if;
        elsif memoryControlWord.MemOp and faultFromMem then
            if memoryControlWord.MemOpIsWrite then
                exception_code <= riscv32_exception_code_store_access_fault;
            else
                exception_code <= riscv32_exception_code_load_access_fault;
            end if;
        end if;
    end process;

    postProcessMemRead : process(dataFromMem, memoryControlWord, requestAddress, csr_in)
        variable memDataRead_buf : riscv32_data_type;
        variable shiftCount : natural range 0 to 31;
    begin
        memDataRead_buf := dataFromMem;
        case memoryControlWord.loadStoreSize is
            when ls_word =>
                -- Do nothing
            when ls_halfword =>
                shiftCount := to_integer(unsigned(requestAddress(1 downto 1)))*16;
                memDataRead_buf := std_logic_vector(shift_right(unsigned(memDataRead_buf), shiftCount));
                if memoryControlWord.memReadSignExtend then
                    memDataRead_buf := std_logic_vector(resize(signed(memDataRead_buf(15 downto 0)), 32));
                else
                    memDataRead_buf(31 downto 16) := (others => '0');
                end if;
            when ls_byte =>
                shiftCount := to_integer(unsigned(requestAddress(1 downto 0)))*8;
                memDataRead_buf := std_logic_vector(shift_right(unsigned(memDataRead_buf), shiftCount));
                if memoryControlWord.memReadSignExtend then
                    memDataRead_buf := std_logic_vector(resize(signed(memDataRead_buf(7 downto 0)), 32));
                else
                    memDataRead_buf(31 downto 8) := (others => '0');
                end if;
        end case;

        if memoryControlWord.csrOp then
            memDataRead_buf := csr_in.data;
        end if;
        memDataRead <= memDataRead_buf;
    end process;

    preProcessAddress : process(requestAddress, memoryControlWord)
        variable addressToMem_buf : riscv32_address_type;
    begin
        addressToMem_buf := requestAddress;
        case memoryControlWord.loadStoreSize is
            when ls_word =>
                -- do nothing
            when ls_halfword =>
                addressToMem_buf(1) := '0';
            when ls_byte =>
                addressToMem_buf(1 downto 0) := (others => '0');
        end case;
        addressToMem <= addressToMem_buf;
    end process;

    preProcessByteMask : process(memoryControlWord, requestAddress)
        variable byteMaskToMem_buf : riscv32_byte_mask_type;
        variable shiftCount : natural range 0 to 4;
    begin
        case memoryControlWord.loadStoreSize is
            when ls_word =>
                byteMaskToMem_buf := "1111";
            when ls_halfword =>
                byteMaskToMem_buf := "0011";
                shiftCount := to_integer(unsigned(requestAddress(1 downto 1)))*2;
                byteMaskToMem_buf := std_logic_vector(shift_left(unsigned(byteMaskToMem_buf), shiftCount));
            when ls_byte =>
                byteMaskToMem_buf := "0001";
                shiftCount := to_integer(unsigned(requestAddress(1 downto 0)));
                byteMaskToMem_buf := std_logic_vector(shift_left(unsigned(byteMaskToMem_buf), shiftCount));
        end case;
        byteMaskToMem <= byteMaskToMem_buf;
    end process;

    preProcessOutgoingData : process(memoryControlWord, rs2Data, requestAddress)
        variable shiftCount : natural range 0 to 31;
    begin
        case memoryControlWord.loadStoreSize is
            when ls_word =>
                memWriteData <= rs2Data;
            when ls_halfword =>
                shiftCount := to_integer(unsigned(requestAddress(1 downto 1)))*16;
                memWriteData <= std_logic_vector(shift_left(unsigned(rs2Data), shiftCount));
            when ls_byte =>
                shiftCount := to_integer(unsigned(requestAddress(1 downto 0)))*8;
                memWriteData <= std_logic_vector(shift_left(unsigned(rs2Data), shiftCount));
        end case;
    end process;

    address_misaligned <= addressToMem(1 downto 0) /= "00";

    -- mem2bus
    dataToMem <= memWriteData;
    memAddress <= addressToMem;
    memByteMask <= byteMaskToMem;
    doMemWrite <= memoryControlWord.MemOp and memoryControlWord.MemOpIsWrite and not address_misaligned;
    doMemRead <= memoryControlWord.MemOp and not memoryControlWord.MemOpIsWrite and not address_misaligned;

    -- csr out
    csrOut.command <= memoryControlWord.csrCmd;
    csrOut.address <= requestAddress(11 downto 0);
    csrOut.data_in <= rs1Data;
    csrOut.do_write <= memoryControlWord.csrOp and memoryControlWord.csrWrite;
    csrOut.do_read <= memoryControlWord.csrOp and memoryControlWord.csrRead;
end architecture;
