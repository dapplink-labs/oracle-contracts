// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IEventManager {
    event VerifyPredictEventSig(uint256 requestId, uint256 totalStaking, bytes32 signatoryRecordHash, string winner);

    struct PredictEvents {
        uint256 requestId;
        string winner;
        bytes32 blockHash;
        uint256 blockNumber;
        bytes32 msgHash;
    }
}
