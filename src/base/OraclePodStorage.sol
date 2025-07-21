// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;


import { IOraclePod } from "../interfaces/IOraclePod.sol";


abstract contract OraclePodStorage is IOraclePod {
    address public oracleManager;

    uint256 public marketPrice;
}
