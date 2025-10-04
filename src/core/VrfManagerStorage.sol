// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/IBLSApkRegistry.sol";
import "../interfaces/IVrfPod.sol";
import "../interfaces/IVrfManager.sol";


abstract contract VrfManagerStorage is IVrfManager{
    IBLSApkRegistry public blsApkRegistry;

    address public aggregatorAddress;

    mapping(IVrfPod => bool) public podIsWhitelistedForFill;
    mapping(address => bool) public operatorWhitelist;
}
