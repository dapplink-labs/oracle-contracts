// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";

import {EventPodStorage} from "./EventPodStorage.sol";

contract EventPod is Initializable, OwnableUpgradeable, EventPodStorage {
    constructor() {
        _disableInitializers();
    }

    modifier onlyEventManager() {
        require(msg.sender == eventManager, "EventPod.onlyEventManager: caller is not the event manager address");
        _;
    }

    function initialize(address _initialOwner, address _eventManager) external initializer {
        __Ownable_init(_initialOwner);
        eventManager = _eventManager;
    }

    function createEvent(
        uint256 _requestId,
        string memory _eventDescribe,
        string memory _predictPosSide,
        string memory _predictNegSide
    ) external {
        predictEventMapping[_requestId] = PredictEventInfo({
            requestId: _requestId,
            eventDescribe: _eventDescribe,
            predictPosSide: _predictPosSide,
            predictNegSide: _predictNegSide,
            winner: "unknown"
        });
        emit CreatePredictEvent(_requestId, _eventDescribe, _predictPosSide, _predictNegSide, address(this));
    }

    function submitEventResult(uint256 _requestId, string memory _winner) external onlyEventManager {
        predictEventMapping[_requestId].winner = _winner;
        emit PredictEventResult(
            _requestId,
            _winner,
            predictEventMapping[_requestId].predictPosSide,
            predictEventMapping[_requestId].predictNegSide
        );
    }

    function fetchEventResult(uint256 requestId)
        external
        view
        returns (string memory predictPosSide, string memory predictNegSid, string memory winner)
    {
        return (
            predictEventMapping[requestId].predictPosSide,
            predictEventMapping[requestId].predictNegSide,
            predictEventMapping[requestId].winner
        );
    }

    function setEventManager(address _eventManager) external onlyOwner {
        eventManager = _eventManager;
    }
}
