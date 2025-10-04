// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IEventPod {

    event CreatePredictEvent(
        uint256 requestId,
        string  eventDescribe,
        string  predictPosSide,
        string  predictNegSid
    );

    event PredictEventResult(
        uint256 requestId,
        string  winner,
        string  predictPosSide,
        string  predictNegSid
    );

    function createEvent(uint256 requestId, string memory eventDescribe, string memory predictPosSide, string memory predictNegSid) external;
    function submitEventResult(uint256 requestId, string memory winner) external;
    function fetchEventResult(uint256 requestId) external view returns (string memory predictPosSide, string memory predictNegSid, string memory winner);
    function setEventManager(address _eventManager) external;
}
