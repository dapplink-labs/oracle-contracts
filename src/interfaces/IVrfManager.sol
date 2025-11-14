// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../libraries/BN254.sol";
import "./IBLSApkRegistry.sol";
import {IVrfPod} from "./IVrfPod.sol";

interface IVrfManager {
    event VerifyVrfSig(uint256 requestId, uint256 totalStaking, bytes32 signatoryRecordHash, uint256[] _randomWords);

    struct VrfRandomWords {
        uint256 requestId;
        uint256[] _randomWords;
        bytes32 blockHash;
        uint256 blockNumber;
        bytes32 msgHash;
    }

    function fillRandWordsWithSignature(
        IVrfPod vrfPod,
        VrfRandomWords calldata vrfRandomWords,
        IBLSApkRegistry.NonSignerAndSignature memory oracleNonSignerAndSignature
    ) external;
}
