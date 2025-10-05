// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import "../libraries/SafeCall.sol";
import "../interfaces/IEventManager.sol";
import "../interfaces/IBLSApkRegistry.sol";
import "../interfaces/IEventPod.sol";

import "./EventManagerStorage.sol";
import "./PodManager.sol";


contract EventManager is OwnableUpgradeable, PodManager, EventManagerStorage {
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _initialOwner,
        address _blsApkRegistry,
        address _aggregatorAddress
    ) external initializer {
        __Ownable_init(_initialOwner);
        __PodManager_init(_blsApkRegistry, _aggregatorAddress);
    }

    function fillEventResultWithSignature(
        IEventPod eventPod,
        PredictEvents calldata predictEvents,
        IBLSApkRegistry.OracleNonSignerAndSignature memory oracleNonSignerAndSignature
    ) external onlyAggregatorManager onlyPodWhitelistedForFill(address(eventPod)) {
        (
            uint256 totalStaking,
            bytes32 signatoryRecordHash
        ) = blsApkRegistry.checkSignatures(predictEvents.msgHash, predictEvents.blockNumber, oracleNonSignerAndSignature);

        string memory winner = predictEvents.winner;

        eventPod.submitEventResult(predictEvents.requestId, predictEvents.winner);

        emit VerifyPredictEventSig(predictEvents.requestId, totalStaking, signatoryRecordHash, winner);
    }
}
