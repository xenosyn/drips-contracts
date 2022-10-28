// SPDX-License-Identifier: GPL-3.0-onl
pragma solidity ^0.8.15;

import {Drips, DripsConfig, DripsHistory, DripsConfigImpl, DripsReceiver,
IReserve, Managed, Splits, SplitsReceiver, IERC20, DripsHub } from "../monger/DripsHub.sol";

contract DripsHubHarness is DripsHub {

    constructor(uint32 cycleSecs_, IReserve reserve_) DripsHub(cycleSecs_, reserve_) {}

    // setting local arrays of structs to pass to setDrips()
    DripsReceiver[] public currReceiversLocal;
    DripsReceiver[] public newReceiversLocal;

    SplitsReceiver[] public currSplitReceiversLocal;

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
        returns (uint256 userId, uint32 dripId, uint160 amtPerSec, uint32 start, uint32 duration) {
        DripsConfig config;
        if (select == true) {  // 1 == newReceiversLocal
            userId = newReceiversLocal[index].userId;
            config = newReceiversLocal[index].config;
        } else {
            userId = currReceiversLocal[index].userId;
            config = currReceiversLocal[index].config;
        }
        dripId = DripsConfigImpl.dripId(config);
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
        thisCycle = _dripsStorage().states[assetId][userId].amtDeltas[cycle].thisCycle;
        nextCycle = _dripsStorage().states[assetId][userId].amtDeltas[cycle].nextCycle;
        nextReceivableCycle = _dripsStorage().states[assetId][userId].nextReceivableCycle;
    }

    // helper that calls setDrips() using the local currReceivers and newReceivers
    function helperSetDrips(
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


    function helperCreateConfig(uint32 dripId, uint160 amtPerSec, uint32 start, uint32 duration)
            public pure returns (DripsConfig) {
        return DripsConfigImpl.create(dripId, amtPerSec, start, duration);
    }


    // simplification of _calcMaxEnd in the case of maximum one DripsReceiver
    function _calcMaxEnd(uint128 balance, DripsReceiver[] memory receivers)
        public override view returns (uint32 maxEnd) {

        require(receivers.length <= 1, "Too many drips receivers");

        if (receivers.length == 0 || balance == 0) {
            maxEnd = uint32(_currTimestamp());
            return maxEnd;
        }

        uint192 amtPerSec = receivers[0].config.amtPerSec();

        if (amtPerSec == 0) {
            maxEnd = uint32(_currTimestamp());
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
    function _updateReceiverStates(
        mapping(uint256 => DripsState) storage states,
        DripsReceiver[] memory currReceivers,
        uint32 lastUpdate,
        uint32 currMaxEnd,
        DripsReceiver[] memory newReceivers,
        uint32 newMaxEnd
    ) internal override {

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
                (uint32 currStart, uint32 currEnd) = _dripsRangeInFuture(currRecv, lastUpdate, currMaxEnd);
                (uint32 newStart, uint32 newEnd) = _dripsRangeInFuture(newRecv, _currTimestamp(), newMaxEnd);
                {
                    int256 amtPerSec = int256(uint256(currRecv.config.amtPerSec()));
                    // Move the start and end times if updated
                    _addDeltaRange(state, currStart, newStart, -amtPerSec);
                    _addDeltaRange(state, currEnd, newEnd, amtPerSec);
                }
                // Ensure that the user receives the updated cycles
                uint32 currStartCycle = _cycleOf(currStart);
                uint32 newStartCycle = _cycleOf(newStart);
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
            (uint32 start, uint32 end) = _dripsRangeInFuture(currRecv, lastUpdate, currMaxEnd);
            int256 amtPerSec = int256(uint256(currRecv.config.amtPerSec()));
            _addDeltaRange(state, start, end, -amtPerSec);
        }

        for (uint i = 0; i < newReceivers.length; i++) {
            DripsReceiver memory newRecv;
            newRecv = newReceivers[i];
            DripsState storage state = states[newRecv.userId];
            (uint32 start, uint32 end) = _dripsRangeInFuture(newRecv, _currTimestamp(), newMaxEnd);
            int256 amtPerSec = int256(uint256(newRecv.config.amtPerSec()));
            _addDeltaRange(state, start, end, amtPerSec);
            // Ensure that the user receives the updated cycles
            uint32 startCycle = _cycleOf(start);
            if (state.nextReceivableCycle == 0 || state.nextReceivableCycle > startCycle) {
                state.nextReceivableCycle = startCycle;
            }
        }
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
        (fromCycle, toCycle) = _receivableDripsCyclesRange(userId, assetId);
        if (toCycle - fromCycle > maxCycles) {
            receivableCycles = toCycle - fromCycle - maxCycles;
            toCycle -= receivableCycles;
        }
        DripsState storage state = _dripsStorage().states[assetId][userId];

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

    // we re-wrote _receiveDrips to perform two time the loops
    function _receiveDrips(
        uint256 userId,
        uint256 assetId,
        uint32 maxCycles
    ) public override
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
            DripsState storage state = _dripsStorage().states[assetId][userId];
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
        uint256 assetId,
        uint32 lastUpdate,
        uint32 currMaxEnd,
        uint32 newMaxEnd
    ) public {
        _updateReceiverStates(
            _dripsStorage().states[assetId],
            currReceiversLocal,
            lastUpdate,
            currMaxEnd,
            newReceiversLocal,
            newMaxEnd
        );
    }

    function helperUpdateReceiverStatesOriginal(
        uint256 assetId,
        uint32 lastUpdate,
        uint32 currMaxEnd,
        uint32 newMaxEnd
    ) public {
        super._updateReceiverStates(
            _dripsStorage().states[assetId],
            currReceiversLocal,
            lastUpdate,
            currMaxEnd,
            newReceiversLocal,
            newMaxEnd
        );
    }

    // setter to verify we have access to _dripsStorage()
    function setBalanceOfUserId (uint256 assetId, uint256 userId, uint128 setValue) public {
        DripsState storage state = _dripsStorage().states[assetId][userId];
        state.balance = setValue;
    }
}
