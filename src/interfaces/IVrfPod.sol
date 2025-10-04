// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IVrfPod {
    event RequestSent(
        uint256 requestId,
        uint256 _numWords,
        address current
    );

    event FillRandomWords(
        uint256 requestId,
        uint256[] randomWords
    );

    function requestRandomWords(uint256 _requestId, uint256 _numWords) external;
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) external;
    function getRequestStatus(uint256 _requestId) external view returns (bool fulfilled, uint256[] memory randomWords);
}
