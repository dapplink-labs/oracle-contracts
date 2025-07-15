// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";

import "../interfaces/IBLSApkRegistry.sol";
import "../interfaces/IOraclePod.sol";


abstract contract OracleManagerStorage is Initializable {
    IBLSApkRegistry public blsApkRegistry;

    uint256 public confirmBatchId;

    address public aggregatorAddress;

    mapping(IOraclePod => bool) public podIsWhitelistedForFill;
    mapping(address => bool) public operatorWhitelist;
}
