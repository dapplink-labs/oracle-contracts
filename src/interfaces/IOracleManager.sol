// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/BN254.sol";
import "./IBLSApkRegistry.sol";
import {IOraclePod} from "./IOraclePod.sol";

interface IOracleManager {
    event VerifyOracleSig(
        uint256 batchId,
        uint256 totalStaking,
        bytes32 signatoryRecordHash,
        string marketPrice
    );

    struct OracleBatch {
        string symbolPrice;
        bytes32 blockHash;
        uint256 blockNumber;
        bytes32 msgHash;
    }

    function fillSymbolPriceWithSignature(
        IOraclePod oraclePod,
        OracleBatch calldata oracleBatch,
        IBLSApkRegistry.OracleNonSignerAndSignature memory oracleNonSignerAndSignature
    ) external;
}
