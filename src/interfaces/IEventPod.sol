// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IEventPod {
    event CreatePredictEvent(
        uint256 requestId,
        string  eventDescribe,
        string  predictPosSide,
        string  predictNegSid,
        address podAddress
    );

    event PredictEventResult(
        uint256 requestId,
        string  winner,
        string  predictPosSide,
        string  predictNegSid
    );

    function createEvent(uint256 _requestId, string memory _eventDescribe, string memory _predictPosSide, string memory _predictNegSide) external;
    function submitEventResult(uint256 _requestId, string memory _winner) external;
    function fetchEventResult(uint256 _requestId) external view returns (string memory predictPosSide, string memory predictNegSid, string memory winner);
    function setEventManager(address _eventManager) external;
}
