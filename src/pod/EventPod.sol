// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;


import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";

import { EventPodStorage } from "./EventPodStorage.sol";

contract EventPod is Initializable, OwnableUpgradeable, EventPodStorage{
    constructor() {
        _disableInitializers();
    }

    modifier onlyEventManager() {
        require (
            msg.sender == eventManager, "EventPod.onlyEventManager: caller is not the oracle manager address"
        );
        _;
    }

    function initialize(address _initialOwner, address _eventManager) external initializer {
        __Ownable_init(_initialOwner);
        eventManager = _eventManager;
    }

    function createEvent(uint256 requestId, string memory eventDescribe, string memory predictPosSide, string memory predictNegSid) external {

    }

    function submitEventResult(uint256 requestId, string memory winner) external onlyEventManager {

    }

    function fetchEventResult(uint256 requestId) external view returns (string memory predictPosSide, string memory predictNegSid, string memory winner) {
        return (predictEventMapping[requestId].predictPosSide, predictEventMapping[requestId].predictNegSide, predictEventMapping[requestId].winner);
    }

    function setEventManager(address _eventManager) external {

    }
}
