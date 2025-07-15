// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/BN254.sol";
import "./IBLSApkRegistry.sol";
import {IOraclePod} from "./IOraclePod.sol";

interface IOracleManager {

    event OperatorRegistered(address indexed operator, string nodeUrl);
    event OperatorDeRegistered(address operator);

    event VerifyOracleSig(
        uint256 batchId,
        uint256 totalStaking,
        bytes32 signatoryRecordHash,
        uint256 marketPrice
    );

    event OraclePodAddedToFillWhitelist(IOraclePod oralePod);
    event OraclePodRemoveToFillWhitelist(IOraclePod oralePod);

    struct OracleBatch {
        uint256 symbolPrice;
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

    function fillSymbolPriceWithSignature(
        IOraclePod oraclePod,
        OracleBatch calldata oracleBatch,
        IBLSApkRegistry.OracleNonSignerAndSignature memory oracleNonSignerAndSignature
    ) external;

    function addOrRemoveOperatorWhitelist(address operator, bool isAdd) external;
    function setAggregatorAddress(address _aggregatorAddress) external;
    function addOraclePodToFillWhitelist(IOraclePod oraclePod) external;
    function removeOraclePodToFillWhitelist(IOraclePod oraclePod) external;
}
