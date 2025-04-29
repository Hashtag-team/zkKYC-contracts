// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.29;

import "./ITest.sol";

contract TestContract is ITest {
    constructor(address recipient) payable {}
}