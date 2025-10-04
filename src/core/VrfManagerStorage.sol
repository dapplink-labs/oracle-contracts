// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";

import "../interfaces/IBLSApkRegistry.sol";
import "../interfaces/IVrfPod.sol";
import "../interfaces/IVrfManager.sol";


abstract contract VrfManagerStorage is Initializable, IVrfManager{
    IBLSApkRegistry public blsApkRegistry;

    address public aggregatorAddress;

    mapping(IVrfPod => bool) public podIsWhitelistedForFill;
    mapping(address => bool) public operatorWhitelist;
}
