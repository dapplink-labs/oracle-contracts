// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../libraries/BN254.sol";
import "./IBLSApkRegistry.sol";
import {IVrfPod} from "./IVrfPod.sol";

interface IVrfManager {
    event OperatorRegistered(address indexed operator, string nodeUrl);
    event OperatorDeRegistered(address operator);

    event VerifyVrfSig(
        uint256 requestId,
        uint256 totalStaking,
        bytes32 signatoryRecordHash,
        uint256[] _randomWords
    );

    event VrfPodAddedToFillWhitelist(IVrfPod oralePod);
    event VrfPodRemoveToFillWhitelist(IVrfPod oralePod);

    struct VrfRandomWords{
        uint256 requestId;
        uint256[] _randomWords;
        bytes32 blockHash;
        uint256 blockNumber;
        bytes32 msgHash;
    }

    struct PubkeyRegistrationParams {
        BN254.G1Point pubkeyRegistrationSignature;
        BN254.G1Point pubkeyG1;
        BN254.G2Point pubkeyG2;
    }

    function registerOperator(string calldata nodeUrl) external;
    function deRegisterOperator() external;

    function fillRandWordsWithSignature(
        IVrfPod vrfPod,
        VrfRandomWords calldata vrfRandomWords,
        IBLSApkRegistry.OracleNonSignerAndSignature memory oracleNonSignerAndSignature
    ) external;

    function addOrRemoveOperatorWhitelist(address operator, bool isAdd) external;
    function setAggregatorAddress(address _aggregatorAddress) external;
    function addVrfPodToFillWhitelist(IVrfPod VrfPod) external;
    function removeVrfPodToFillWhitelist(IVrfPod VrfPod) external;
}
