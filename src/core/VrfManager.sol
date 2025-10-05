// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import "../libraries/SafeCall.sol";
import "../interfaces/IVrfManager.sol";
import "../interfaces/IBLSApkRegistry.sol";
import "../interfaces/IVrfPod.sol";

import "./PodManager.sol";
import "./VrfManagerStorage.sol";


contract VrfManager is OwnableUpgradeable, PodManager, VrfManagerStorage {
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

    function fillRandWordsWithSignature(
        IVrfPod vrfPod,
        VrfRandomWords calldata vrfRandomWords,
        IBLSApkRegistry.OracleNonSignerAndSignature memory oracleNonSignerAndSignature
    ) external onlyAggregatorManager onlyPodWhitelistedForFill(address(vrfPod)) {
        (
            uint256 totalStaking,
            bytes32 signatoryRecordHash
        ) = blsApkRegistry.checkSignatures(vrfRandomWords.msgHash, vrfRandomWords.blockNumber, oracleNonSignerAndSignature);

        vrfPod.fulfillRandomWords(vrfRandomWords.requestId, vrfRandomWords._randomWords);

        emit VerifyVrfSig(vrfRandomWords.requestId, totalStaking, signatoryRecordHash, vrfRandomWords._randomWords);
    }
}
