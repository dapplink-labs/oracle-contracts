// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;


import { IOraclePod } from "../interfaces/IOraclePod.sol";


abstract contract OraclePodStorage is IOraclePod {
    address public oracleManager;

    string public marketPrice;

    uint256 public updateTimestamp;

    uint256 public constant maxAge = 1 days;
}
