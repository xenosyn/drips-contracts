// SPDX-License-Identifier: GPL-3.0-onl
pragma solidity ^0.8.15;

import {Drips, DripsConfig, DripsHistory, DripsConfigImpl, DripsReceiver} from "../../src/Drips.sol";
import {IReserve} from "../../src/Reserve.sol";
import {Managed} from "../../src/Managed.sol";
import {Splits, SplitsReceiver} from "../../src/Splits.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {DripsHub} from "../../src/DripsHub.sol";


contract DripsHubHarness is DripsHub {

    constructor(uint32 cycleSecs_, IReserve reserve_) DripsHub(cycleSecs_, reserve_) {}

    bytes32 public immutable dripsHubStorageSlot = erc1967Slot("eip1967.dripsHub.storage");
    bytes32 public immutable pausedStorageSlot = erc1967Slot("eip1967.managed.paused");
    bytes32 public immutable dripsStorageSlot = erc1967Slot("eip1967.drips.storage");
    bytes32 public immutable splitsStorageSlot = erc1967Slot("eip1967.splits.storage");

    // setting local arrays of structs to pass to setDrips()
    DripsReceiver[] public currReceiversLocal;
    DripsReceiver[] public newReceiversLocal;

    SplitsReceiver[] public currSplitReceiversLocal;

    function __dripsStorage() private view returns (DripsStorage storage dripsStorage) {
        bytes32 slot = dripsStorageSlot;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            dripsStorage.slot := slot
        }
    }

    function setDripsReceiverLocalArr(bool select, uint index, uint256 receiverId, DripsConfig config) public {
        if (select == true) {  // 1 == newReceiversLocal
            newReceiversLocal[index].userId = receiverId;
            newReceiversLocal[index].config = config;
        } else {
            currReceiversLocal[index].userId = receiverId;
            currReceiversLocal[index].config = config;
        }
    }

    function getDripsReceiverLocalArr(bool select, uint index)
        public view
        returns (uint256 userId, uint192 amtPerSec, uint32 start, uint32 duration) {
        DripsConfig config;
        if (select == true) {  // 1 == newReceiversLocal
            userId = newReceiversLocal[index].userId;
            config = newReceiversLocal[index].config;
        } else {
            userId = currReceiversLocal[index].userId;
            config = currReceiversLocal[index].config;
        }
        amtPerSec = DripsConfigImpl.amtPerSec(config);
        start = DripsConfigImpl.start(config);
        duration = DripsConfigImpl.duration(config);
    }

    function getDripsReceiverLocalLength(bool select) public view returns (uint256 length) {
        if (select == true) {  // 1 == newReceiversLocal
            length = newReceiversLocal.length;
        } else {
            length = currReceiversLocal.length;
        }
    }

    function getRelevantStateVars(uint256 assetId, uint256 userId, uint32 cycle)
        public view
        returns (int128 thisCycle, int128 nextCycle, uint32 nextReceivableCycle) {
        thisCycle = __dripsStorage().states[assetId][userId].amtDeltas[cycle].thisCycle;
        nextCycle = __dripsStorage().states[assetId][userId].amtDeltas[cycle].nextCycle;
        nextReceivableCycle = __dripsStorage().states[assetId][userId].nextReceivableCycle;
    }

    // helper that calls setDrips() using the local currReceivers and newReceivers
    function _newHelperSetDrips(
        uint256 userId,
        IERC20 erc20,
        int128 balanceDelta
    ) external {
        setDrips(userId, erc20, currReceiversLocal, balanceDelta, newReceiversLocal);
    }

    // helper that calls split() using the local currSplitReceiversLocal
    function helperSplit(
        uint256 userId,
        IERC20 erc20
    ) external returns (uint128 collectableAmt, uint128 splitAmt){
        return split(userId, erc20, currSplitReceiversLocal);
    }


    function _helperCreateConfig(uint32 dripId, uint160 amtPerSec, uint32 start, uint32 duration)
            public pure returns (DripsConfig) {
        return DripsConfigImpl.create(dripId, amtPerSec, start, duration);
    }


    // simplification of _calcMaxEnd in the case of maximum one DripsReceiver
    function __calcMaxEnd(uint128 balance, DripsReceiver[] memory receivers)
        internal view returns (uint32 maxEnd) {

        require(receivers.length <= 1, "Too many drips receivers");

        if (receivers.length == 0 || balance == 0) {
            maxEnd = uint32(__currTimestamp());
            return maxEnd;
        }

        uint192 amtPerSec = receivers[0].config.amtPerSec();

        if (amtPerSec == 0) {
            maxEnd = uint32(__currTimestamp());
            return maxEnd;
        }

        uint32 start = receivers[0].config.start();
        uint32 duration = receivers[0].config.duration();
        uint32 end;

        if (duration == 0) {  // duration == 0 -> user requests to drip until end of balance
            end = type(uint32).max;
        } else {
            end = start + duration;
        }

        if (balance / amtPerSec > end - start) {
            maxEnd = end;
        } else {
            maxEnd = start + uint32(balance / amtPerSec);
        }

        return maxEnd;
    }

    // simplified version of _updateReceiverStates():
    function __updateReceiverStates(
        mapping(uint256 => DripsState) storage states,
        DripsReceiver[] memory currReceivers,
        uint32 lastUpdate,
        uint32 currMaxEnd,
        DripsReceiver[] memory newReceivers,
        uint32 newMaxEnd
    ) internal {

        require (currReceivers.length == 1, "");
        require (newReceivers.length == 1, "");
        DripsReceiver memory currRecv;
        currRecv = currReceivers[0];
        DripsReceiver memory newRecv;
        newRecv = newReceivers[0];
        require ((currRecv.userId == newRecv.userId) &&
                (currRecv.config.amtPerSec() == newRecv.config.amtPerSec()), "");

        if (currReceivers.length == 1 && newReceivers.length == 1) {
            DripsReceiver memory currRecv;
            currRecv = currReceivers[0];
            DripsReceiver memory newRecv;
            newRecv = newReceivers[0];

            if ((currRecv.userId == newRecv.userId) &&
                (currRecv.config.amtPerSec() == newRecv.config.amtPerSec())) {

                DripsState storage state = states[currRecv.userId];
                (uint32 currStart, uint32 currEnd) = __dripsRangeInFuture(currRecv, lastUpdate, currMaxEnd);
                (uint32 newStart, uint32 newEnd) = __dripsRangeInFuture(newRecv, __currTimestamp(), newMaxEnd);
                {
                    int256 amtPerSec = int256(uint256(currRecv.config.amtPerSec()));
                    // Move the start and end times if updated
                    __addDeltaRange(state, currStart, newStart, -amtPerSec);
                    __addDeltaRange(state, currEnd, newEnd, amtPerSec);
                }
                // Ensure that the user receives the updated cycles
                uint32 currStartCycle = __cycleOf(currStart);
                uint32 newStartCycle = __cycleOf(newStart);
                if (currStartCycle > newStartCycle && state.nextReceivableCycle > newStartCycle) {
                    state.nextReceivableCycle = newStartCycle;
                }

                return;
            }
        }

        for (uint i = 0; i < currReceivers.length; i++) {
            DripsReceiver memory currRecv;
            currRecv = currReceivers[i];
            DripsState storage state = states[currRecv.userId];
            (uint32 start, uint32 end) = __dripsRangeInFuture(currRecv, lastUpdate, currMaxEnd);
            int256 amtPerSec = int256(uint256(currRecv.config.amtPerSec()));
            __addDeltaRange(state, start, end, -amtPerSec);
        }

        for (uint i = 0; i < newReceivers.length; i++) {
            DripsReceiver memory newRecv;
            newRecv = newReceivers[i];
            DripsState storage state = states[newRecv.userId];
            (uint32 start, uint32 end) = __dripsRangeInFuture(newRecv, __currTimestamp(), newMaxEnd);
            int256 amtPerSec = int256(uint256(newRecv.config.amtPerSec()));
            __addDeltaRange(state, start, end, amtPerSec);
            // Ensure that the user receives the updated cycles
            uint32 startCycle = __cycleOf(start);
            if (state.nextReceivableCycle == 0 || state.nextReceivableCycle > startCycle) {
                state.nextReceivableCycle = startCycle;
            }
        }
    }

/// @notice Calculates the time range in the future in which a receiver will be dripped to.
    /// @param receiver The drips receiver
    /// @param maxEnd The maximum end time of drips
    function __dripsRangeInFuture(DripsReceiver memory receiver, uint32 updateTime, uint32 maxEnd)
        private
        view
        returns (uint32 start, uint32 end)
    {
        return __dripsRange(receiver, updateTime, maxEnd, __currTimestamp(), type(uint32).max);
    }

    /// @notice Calculates the time range in which a receiver is to be dripped to.
    /// This range is capped to provide a view on drips through a specific time window.
    /// @param receiver The drips receiver
    /// @param updateTime The time when drips are configured
    /// @param maxEnd The maximum end time of drips
    /// @param startCap The timestamp the drips range start should be capped to
    /// @param endCap The timestamp the drips range end should be capped to
    function __dripsRange(
        DripsReceiver memory receiver,
        uint32 updateTime,
        uint32 maxEnd,
        uint32 startCap,
        uint32 endCap
    ) private pure returns (uint32 start, uint32 end_) {
        start = receiver.config.start();
        if (start == 0) {
            start = updateTime;
        }
        uint40 end = uint40(start) + receiver.config.duration();
        if (end == start || end > maxEnd) {
            end = maxEnd;
        }
        if (start < startCap) {
            start = startCap;
        }
        if (end > endCap) {
            end = endCap;
        }
        if (end < start) {
            end = start;
        }
        return (start, uint32(end));
    }

    /// @notice Adds funds received by a user in a given time range
    /// @param state The user state
    /// @param start The timestamp from which the delta takes effect
    /// @param end The timestamp until which the delta takes effect
    /// @param amtPerSec The dripping rate
    function __addDeltaRange(DripsState storage state, uint32 start, uint32 end, int256 amtPerSec)
        private
    {
        if (start == end) {
            return;
        }
        mapping(uint32 => AmtDelta) storage amtDeltas = state.amtDeltas;
        __addDelta(amtDeltas, start, amtPerSec);
        __addDelta(amtDeltas, end, -amtPerSec);
    }

    /// @notice Adds delta of funds received by a user at a given time
    /// @param amtDeltas The user amount deltas
    /// @param timestamp The timestamp when the deltas need to be added
    /// @param amtPerSec The dripping rate
    function __addDelta(
        mapping(uint32 => AmtDelta) storage amtDeltas,
        uint256 timestamp,
        int256 amtPerSec
    ) private {
        unchecked {
            // In order to set a delta on a specific timestamp it must be introduced in two cycles.
            // These formulas follow the logic from `_drippedAmt`, see it for more details.
            int256 amtPerSecMultiplier = int256(_AMT_PER_SEC_MULTIPLIER);
            int256 fullCycle = (int256(uint256(_cycleSecs)) * amtPerSec) / amtPerSecMultiplier;
            int256 nextCycle = (int256(timestamp % _cycleSecs) * amtPerSec) / amtPerSecMultiplier;
            AmtDelta storage amtDelta = amtDeltas[__cycleOf(uint32(timestamp))];
            // Any over- or under-flows are fine, they're guaranteed to be fixed by a matching
            // under- or over-flow from the other call to `_addDelta` made by `_addDeltaRange`.
            // This is because the total balance of `Drips` can never exceed `type(int128).max`,
            // so in the end no amtDelta can have delta higher than `type(int128).max`.
            amtDelta.thisCycle += int128(fullCycle - nextCycle);
            amtDelta.nextCycle += int128(nextCycle);
        }
    }

    /// @notice Calculates the cycle containing the given timestamp.
    /// @param timestamp The timestamp.
    /// @return cycle The cycle containing the timestamp.
    function __cycleOf(uint32 timestamp) private view returns (uint32 cycle) {
        unchecked {
            return timestamp / _cycleSecs + 1;
        }
    }

    /// @notice The current timestamp, casted to the contract's internal representation.
    /// @return timestamp The current timestamp
    function __currTimestamp() private view returns (uint32 timestamp) {
        return uint32(block.timestamp);
    }

    // we re-wrote _receivableDripsVerbose to perform two time the loops
    function _receivableDripsVerbose(
        uint256 userId,
        uint256 assetId,
        uint32 maxCycles
    )
        internal
        view
        returns (
            uint128 receivedAmt,
            uint32 receivableCycles,
            uint32 fromCycle,
            uint32 toCycle,
            int128 amtPerCycle
        )
    {
        (fromCycle, toCycle) = __receivableDripsCyclesRange(userId, assetId);
        if (toCycle - fromCycle > maxCycles) {
            receivableCycles = toCycle - fromCycle - maxCycles;
            toCycle -= receivableCycles;
        }
        DripsState storage state = __dripsStorage().states[assetId][userId];

        uint32 midCycle = (fromCycle + toCycle) / 2;

        for (uint32 cycle = fromCycle; cycle < midCycle; cycle++) {
            amtPerCycle += state.amtDeltas[cycle].thisCycle;
            receivedAmt += uint128(amtPerCycle);
            amtPerCycle += state.amtDeltas[cycle].nextCycle;
        }
        for (uint32 cycle = midCycle; cycle < toCycle; cycle++) {
            amtPerCycle += state.amtDeltas[cycle].thisCycle;
            receivedAmt += uint128(amtPerCycle);
            amtPerCycle += state.amtDeltas[cycle].nextCycle;
        }
    }

    /// @notice Calculates the cycles range from which drips can be received.
    /// @param userId The user ID
    /// @param assetId The used asset ID
    /// @return fromCycle The cycle from which funds can be received
    /// @return toCycle The cycle to which funds can be received
    function __receivableDripsCyclesRange(uint256 userId, uint256 assetId)
        public
        view
        returns (uint32 fromCycle, uint32 toCycle)
    {
        fromCycle = __dripsStorage().states[assetId][userId].nextReceivableCycle;
        toCycle = __cycleOf(__currTimestamp());
        if (fromCycle == 0 || toCycle < fromCycle) {
            toCycle = fromCycle;
        }
    }

    // we re-wrote _receiveDrips to perform two time the loops
    function __receiveDrips(
        uint256 userId,
        uint256 assetId,
        uint32 maxCycles
    ) public
        returns (uint128 receivedAmt, uint32 receivableCycles) {
        uint32 fromCycle;
        uint32 toCycle;
        int128 finalAmtPerCycle;
        (
            receivedAmt,
            receivableCycles,
            fromCycle,
            toCycle,
            finalAmtPerCycle
        ) = _receivableDripsVerbose(userId, assetId, maxCycles);
        if (fromCycle != toCycle) {
            DripsState storage state = __dripsStorage().states[assetId][userId];
            state.nextReceivableCycle = toCycle;
            mapping(uint32 => AmtDelta) storage amtDeltas = state.amtDeltas;

            uint32 midCycle = (fromCycle + toCycle) / 2;

            for (uint32 cycle = fromCycle; cycle < midCycle; cycle++) {
            //for (uint32 cycle = fromCycle; cycle < toCycle; cycle++) {
                delete amtDeltas[cycle];
            }
            for (uint32 cycle = midCycle; cycle < toCycle; cycle++) {
            //for (uint32 cycle = fromCycle; cycle < toCycle; cycle++) {
                delete amtDeltas[cycle];
            }
            // The next cycle delta must be relative to the last received cycle, which got zeroed.
            // In other words the next cycle delta must be an absolute value.
            if (finalAmtPerCycle != 0) amtDeltas[toCycle].thisCycle += finalAmtPerCycle;
        }
        emit ReceivedDrips(userId, assetId, receivedAmt, receivableCycles);
    }


    // helper functions to evaluate the re-write of updateReceiverStates
    // to access the original function, we use super.
    function helperUpdateReceiverStates(
        //mapping(uint256 => DripsState) storage states,
        //DripsReceiver[] memory currReceivers,
        uint256 assetId,
        //uint256 userId,
        uint32 lastUpdate,
        uint32 currMaxEnd,
        //DripsReceiver[] memory newReceivers,
        uint32 newMaxEnd
    //) private {
    ) public {
        //DripsState storage state = _dripsStorage().states[assetId][userId];

        __updateReceiverStates(
            __dripsStorage().states[assetId],
            currReceiversLocal,
            lastUpdate,
            currMaxEnd,
            newReceiversLocal,
            newMaxEnd
        );
    }

    function helperUpdateReceiverStatesOriginal(
        //mapping(uint256 => DripsState) storage states,
        //DripsReceiver[] memory currReceivers,
        uint256 assetId,
        //uint256 userId,
        uint32 lastUpdate,
        uint32 currMaxEnd,
        //DripsReceiver[] memory newReceivers,
        uint32 newMaxEnd
    //) private {
    ) public {
        //DripsState storage state = _dripsStorage().states[assetId][userId];

        // TODO
        // super._updateReceiverStates(
        //     __dripsStorage().states[assetId],
        //     currReceiversLocal,
        //     lastUpdate,
        //     currMaxEnd,
        //     newReceiversLocal,
        //     newMaxEnd
        // );
    }

    function getCycleSecs() public view returns (uint32) {
        return Drips._cycleSecs;
    }

    // setter to verify we have access to _dripsStorage()
    function setBalanceOfUserId (uint256 assetId, uint256 userId, uint128 setValue) public {
        DripsState storage state = __dripsStorage().states[assetId][userId];
        state.balance = setValue;
    }

}
