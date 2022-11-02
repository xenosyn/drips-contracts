// ///////////////////////////////////////////////////////////////
// rule ideas for verification of the functions in Splits.sol
// ///////////////////////////////////////////////////////////////

methods {
    // upgradeTo(address) => HAVOC_ALL
    // upgradeToAndCall(address, bytes) => HAVOC_ALL
    // splitResults(uint256, bool, uint128) returns (uint128, uint128)
}

// sanity rule - must always fail
rule sanity(method f){
    env e;
    calldataarg args;
    f(e,args);
    assert false;
}


// _splittable(uint256 userId, uint256 assetId) - view function, returns (uint128 amt)


// _splitResults(uint256 userId, SplitsReceiver[] memory currReceivers, uint128 amount)
// returns (uint128 collectableAmt, uint128 splitAmt)
//
// assert amount >= collectableAmt;
// assert amount >= splitAmt;
// assert amount == collectableAmt + splitAmt;

rule verifySplitResults() {
    env e;
    uint256 userId;
    uint128 amount;
    uint128 collectableAmt;
    uint128 splitAmt;

    collectableAmt = splitResults(e, userId, true, amount);

    assert amount >= collectableAmt;

    //assert false; // sanity
}


// _split(uint256 userId, uint256 assetId, SplitsReceiver[] memory currReceivers)
// returns (uint128 collectableAmt, uint128 splitAmt)
//
// assert splitsStates[userId].balances[assetId].balance.splittable Before >= After;
// assert splitsStates[userId].balances[assetId].balance.collectable After >= Before;
// assert splittableBefore >= splittableAfter + collectableAfter - collectableBefore;

rule verifySplit() {
    env e;
    uint256 userId;
    uint256 assetId;
    uint128 collectableAmt;
    uint128 splitAmt;

    uint128 splittableBefore;
    uint128 splittableAfter;
    uint128 collectableBefore;
    uint128 collectableAfter;

    splittableBefore = _splittable(e, userId, assetId);
    collectableBefore = _collectable(e, userId, assetId);

    collectableAmt, splitAmt = split(e, userId, assetId, true);

    splittableAfter = _splittable(e, userId, assetId);
    collectableAfter = _collectable(e, userId, assetId);

    assert splittableBefore >= splittableAfter;
    assert collectableBefore <= collectableAfter;
    assert splittableBefore >= splittableAfter + collectableAfter - collectableBefore;

    //assert false;  // sanity
}


// _collectable(uint256 userId, uint256 assetId) - view function returns (uint128 amt)


// _collect(uint256 userId, uint256 assetId) returns (uint128 amt)
// rule 1: after running _collect() -> collectable must be zero
// _collect(userId, assetId);
// assert _splitsStorage().splitsStates[userId].balances[assetId].collectable == 0;
//
// rule 2: collect() should not revert:
// _collect@withrevert(userId, assetId);
// assert !lastReverted;


rule verifyCollect1() {
    env e;
    uint256 userId;
    uint256 assetId;
    uint128 collectedAmt;

    uint128 collectableBefore;
    uint128 collectableAfter;

    collectableBefore = _collectable(e, userId, assetId);
    collectedAmt = _collect(e, userId, assetId);
    collectableAfter = _collectable(e, userId, assetId);

    assert collectableAfter == 0;

    //assert false;  // sanity
}

rule verifyCollect2() {
    env e;
    uint256 userId;
    uint256 assetId;
    uint128 collectedAmt;

    require e.msg.sender != 0;  // prevents revert
    require e.msg.value == 0;  // prevents revert

    collectedAmt = _collect@withrevert(e, userId, assetId);
    assert !lastReverted;

    //assert false;  // sanity
}


// _give(uint256 userId, uint256 receiver, uint256 assetId, uint128 amt)
//
// rule 1: the splittable of the receiver must increase by amt
// assert splittableAfter[receiver] == splittableBefore[receiver] + amt;
//
// rule 2: the splittable of any other user that is not receiver should not change
// require user != receiver;
// assert splittableBefore[user] == splittableAfter[user];

rule verifyGive1() {
    env e;
    uint256 userId;
    uint256 receiver;
    uint256 assetId;
    uint128 amt;

    uint128 splittableBefore;
    uint128 splittableAfter;

    splittableBefore = _splittable(e, receiver, assetId);
    _give(e, userId, receiver, assetId, amt);
    splittableAfter = _splittable(e, receiver, assetId);

    assert splittableAfter == splittableBefore + amt;

    // assert false;  // sanity
}

rule verifyGive2() {
    env e;
    uint256 userId;
    uint256 receiver;
    uint256 assetId;
    uint128 amt;
    uint256 otherUser;

    uint128 splittableBefore;
    uint128 splittableAfter;

    require otherUser != receiver;

    splittableBefore = _splittable(e, otherUser, assetId);
    _give(e, userId, receiver, assetId, amt);
    splittableAfter = _splittable(e, otherUser, assetId);

    assert splittableAfter == splittableBefore;

    // assert false;  // sanity
}


// _setSplits(uint256 userId, SplitsReceiver[] memory receivers)
//
// rule 1: if the receivers list are different, the hash must be different
// require receivers1 != receivers2;
// _assertSplitsValid(receivers1);
// _assertSplitsValid(receivers2);
// assert _hashSplits(receivers1) != _hashSplits(receivers2);

rule verifyHashSplits() {
    env e;
    uint256 length1; uint256 length2;
    uint256 index;
    uint256 userId1; uint32 weight1;
    uint256 userId2; uint32 weight2;
    bytes32 receiversHash1; bytes32 receiversHash2;

    length1 = getCurrSplitsReceiverLocaLength(e, true);
    length2 = getCurrSplitsReceiverLocaLength(e, false);

    //require length1 == length2;
    //require length1 % 32 == 0;  // this requirement generates vacuity!
    //require length1 % 8 == 0;  // attempt to provide a whole word to abi.encode()
    require length1 > 0;
    //require length1 < 7 * 32;

    userId1, weight1 = getCurrSplitsReceiverLocalArr(e, true, index);
    userId2, weight2 = getCurrSplitsReceiverLocalArr(e, false, index);

    receiversHash1 = hashSplits(e, true);
    receiversHash2 = hashSplits(e, false);
    //assert false;  // this vacuity check is not reached when length1 % 32 == 0;

    assert (receiversHash1 == receiversHash2) => (length1 == length2);
    assert (receiversHash1 == receiversHash2) => (userId1 == userId2);
    assert (receiversHash1 == receiversHash2) => (weight1 == weight2);

    // assert false;  // sanity
}
