// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.15;

import {Splits, SplitsReceiver} from "../monger/DripsHub.sol";

contract SplitsHarness is Splits {

    constructor() Splits(bytes32(uint256(1024))) {}

    SplitsReceiver[] public currSplitReceiversLocal1;
    SplitsReceiver[] public currSplitReceiversLocal2;

    function getCurrSplitsReceiverLocalArr(bool selectCurrSplitReceivers, uint256 index
    ) public view returns (uint256 userId, uint32 weight) {
        if (selectCurrSplitReceivers) {
            userId = currSplitReceiversLocal1[index].userId;
            weight = currSplitReceiversLocal1[index].weight;
        } else {
            userId = currSplitReceiversLocal2[index].userId;
            weight = currSplitReceiversLocal2[index].weight;
        }
    }

    function getCurrSplitsReceiverLocaLength(bool selectCurrSplitReceivers
    ) public view returns (uint256 length) {
        if (selectCurrSplitReceivers) {
            length = currSplitReceiversLocal1.length;
        } else {
            length = currSplitReceiversLocal2.length;
        }
    }

    function splitResults(uint256 userId, bool selectCurrSplitReceivers, uint128 amount
    ) public view returns (uint128 collectableAmt) {
        if (selectCurrSplitReceivers) {
            return _splitResult(userId, currSplitReceiversLocal1, amount);
        } else {
            return _splitResult(userId, currSplitReceiversLocal2, amount);
        }
    }

    function split(uint256 userId, uint256 assetId, bool selectCurrSplitReceivers
    ) public returns (uint128 collectableAmt, uint128 splitAmt) {
        if (selectCurrSplitReceivers) {
            return _split(userId, assetId, currSplitReceiversLocal1);
        } else {
            return _split(userId, assetId, currSplitReceiversLocal2);
        }
    }

    function setSplits(uint256 userId, bool selectCurrSplitReceivers
    ) public {
        if (selectCurrSplitReceivers) {
            _setSplits(userId, currSplitReceiversLocal1);
        } else {
            _setSplits(userId, currSplitReceiversLocal2);
        }
    }

    function assertSplitsValid(bool selectCurrSplitReceivers, bytes32 receiversHash
    ) public {
        if (selectCurrSplitReceivers) {
            _assertSplitsValid(currSplitReceiversLocal1, receiversHash);
        } else {
            _assertSplitsValid(currSplitReceiversLocal2, receiversHash);
        }
    }

    function assertCurrSplits(uint256 userId, bool selectCurrSplitReceivers
    ) public view {
        if (selectCurrSplitReceivers) {
            return _assertCurrSplits(userId, currSplitReceiversLocal1);
        } else {
            return _assertCurrSplits(userId, currSplitReceiversLocal2);
        }
    }

    function hashSplits(bool selectCurrSplitReceivers
    ) public view returns (bytes32 receiversHash) {
        if (selectCurrSplitReceivers) {
            return _hashSplits(currSplitReceiversLocal1);
        } else {
            return _hashSplits(currSplitReceiversLocal2);
        }
    }

}
