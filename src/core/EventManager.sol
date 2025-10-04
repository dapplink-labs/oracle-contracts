// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import "../libraries/SafeCall.sol";
import "../interfaces/IEventManager.sol";
import "../interfaces/IBLSApkRegistry.sol";
import "../interfaces/IEventPod.sol";

import "./EventManagerStorage.sol";

contract EventManager is OwnableUpgradeable, EventManagerStorage {
    constructor(){

    }
}
