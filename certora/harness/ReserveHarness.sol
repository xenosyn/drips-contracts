// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.15;

import {Reserve} from "../../src/Reserve.sol";

contract ReserveHarness is Reserve {
    constructor(address owner) Reserve(owner) {}
}
