library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.riscv32_pkg.all;

entity riscv32_pipeline_branchPredictor is
    port (
        clk : in std_logic;
        rst : in boolean;
        stall : in boolean;

        -- Inputs from ID
        currentIDProgramCounter : in riscv32_address_type;
        executeControlWordFromID : in riscv32_ExecuteControlWord_type;
        branchTargetAddressFromID : in riscv32_address_type;
        exceptionTypeFromID : in riscv32_pipeline_exception_type;
        IDContainsBubble : in boolean;

        -- Inputs from EX
        branchIsTakenFromEX : in boolean;
        branchIsNotTakenFromEX : in boolean;
        branchTargetAddressFromEX : in riscv32_address_type;
        
        -- Outputs
        stallAwaitingBranchResolution : out boolean;
        handleMisPrediction : out boolean;
        takeBranch : out boolean;
        branchTarget : out riscv32_address_type
    );
end entity;

architecture behavioural of riscv32_pipeline_branchPredictor is
    type state_type is (idle, awaiting_resolution, handling_prediction, control_transfer_during_prediction_handling);
    
    signal cur_state : state_type := idle;
    signal next_state : state_type := idle;

    signal exIsResolvingBranch : boolean;

    signal isJalrInstruction : boolean;
    signal isBranchInstruction : boolean;
    signal isControlTransferInstruction : boolean;

    signal targetAddressOnMisprediction : riscv32_address_type;

    signal nextPredictionIsTaken : boolean;
    signal updatePredictor : boolean;

    signal isMisPrediction : boolean;
begin

    exIsResolvingBranch <= branchIsTakenFromEX or branchIsNotTakenFromEX;
    isControlTransferInstruction <= isJalrInstruction or isBranchInstruction;
    
    determine_misPrediction : process(nextPredictionIsTaken, branchIsTakenFromEX, branchIsNotTakenFromEX) 
    begin
        if nextPredictionIsTaken then
            isMisPrediction <= branchIsNotTakenFromEX;
        else
            isMisPrediction <= branchIsTakenFromEX;
        end if;
    end process;

    determine_instruction_type : process(executeControlWordFromID, exceptionTypeFromID, IDContainsBubble)
        variable is_branch_op : boolean;
        variable branch_cmd : riscv32_branch_cmd;
        variable ignore_input : boolean;
    begin
        ignore_input := IDContainsBubble or exceptionTypeFromID /= exception_none;
        is_branch_op := executeControlWordFromID.is_branch_op;
        branch_cmd := executeControlWordFromID.branch_cmd;
        if not is_branch_op or ignore_input then
            isJalrInstruction <= false;
            isBranchInstruction <= false;
        elsif branch_cmd = cmd_branch_jalr then
            isJalrInstruction <= true;
            isBranchInstruction <= false;
        else 
            isJalrInstruction <= false;
            isBranchInstruction <= true;
        end if;
    end process;

    cur_state_handling : process(clk)
    begin
        if rising_edge(clk) then
            if rst then
                cur_state <= idle;
            elsif not stall then
                cur_state <= next_state;
            end if;
        end if;
    end process;

    next_state_handling : process(cur_state, isJalrInstruction, isBranchInstruction, nextPredictionIsTaken, exIsResolvingBranch, isMisPrediction, isControlTransferInstruction)
    begin
        next_state <= cur_state;
        case cur_state is
            when idle =>
                if isJalrInstruction then
                    next_state <= awaiting_resolution;
                elsif isBranchInstruction then
                    next_state <= handling_prediction;
                end if;
            when awaiting_resolution | handling_prediction =>
                if isControlTransferInstruction and exIsResolvingBranch and not isMisPrediction then
                    next_state <= awaiting_resolution;
                elsif isControlTransferInstruction and not isMisPrediction then
                    next_state <= control_transfer_during_prediction_handling;
                elsif exIsResolvingBranch then
                    next_state <= idle;
                end if;
            when control_transfer_during_prediction_handling =>
                if isMisPrediction then
                    next_state <= idle;
                elsif exIsResolvingBranch then
                    next_state <= awaiting_resolution;
                end if;
        end case;
    end process;

    state_output : process(cur_state, isJalrInstruction, isBranchInstruction, nextPredictionIsTaken, branchIsTakenFromEX, exIsResolvingBranch, isMisPrediction, isControlTransferInstruction, stall, branchTargetAddressFromID, branchTargetAddressFromEX, targetAddressOnMisprediction)
    begin
        case cur_state is
            when idle =>
                stallAwaitingBranchResolution <= isJalrInstruction;
                handleMisPrediction <= false;
                takeBranch <= isBranchInstruction and nextPredictionIsTaken;
                branchTarget <= branchTargetAddressFromID;
                updatePredictor <= false;
            when awaiting_resolution =>
                stallAwaitingBranchResolution <= true;
                handleMisPrediction <= false;
                takeBranch <= branchIsTakenFromEX;
                branchTarget <= branchTargetAddressFromEX;
                updatePredictor <= false;
            when handling_prediction =>
                stallAwaitingBranchResolution <= isControlTransferInstruction and not isMisPrediction;
                handleMisPrediction <= not stall and isMisPrediction;
                takeBranch <= not stall and isMisPrediction;
                branchTarget <= targetAddressOnMisprediction;
                updatePredictor <= exIsResolvingBranch;
            when control_transfer_during_prediction_handling =>
                stallAwaitingBranchResolution <= true;
                handleMisPrediction <= isMisPrediction;
                takeBranch <= isMisPrediction;
                branchTarget <= targetAddressOnMisprediction;
                updatePredictor <= exIsResolvingBranch;
        end case;
    end process;

    store_misprediction_address : process(clk)
    begin
        if rising_edge(clk) then
            if cur_state = idle and next_state /= idle then
                if nextPredictionIsTaken then
                    targetAddressOnMisprediction <= std_logic_vector(unsigned(currentIDProgramCounter) + 4);
                else
                    targetAddressOnMisprediction <= branchTargetAddressFromID;
                end if;
            end if;
        end if;
    end process;

    branch_predictor : process(clk)
        subtype predictorRange is integer range -1 to 1;
        variable nextBranchExpectedTaken : boolean := true;
        variable predictorState : predictorRange := 0;
    begin
        if rising_edge(clk) then
            if updatePredictor and not stall then
                if branchIsNotTakenFromEX then
                    predictorState := maximum(predictorRange'low, predictorState - 1);
                else
                    predictorState := minimum(predictorRange'high, predictorState + 1);
                end if;
            end if;
            
            if predictorState > 0 then
                nextBranchExpectedTaken := true;
            elsif predictorState < 0 then
                nextBranchExpectedTaken := false;
            end if;
        end if;
        nextPredictionIsTaken <= nextBranchExpectedTaken;
    end process;
end architecture;
