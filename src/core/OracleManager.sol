// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import "../libraries/SafeCall.sol";
import "../interfaces/IOracleManager.sol";
import "../interfaces/IBLSApkRegistry.sol";
import "../interfaces/IOraclePod.sol";

import "./OracleManagerStorage.sol";
import "./PodManager.sol";

contract OracleManager is OwnableUpgradeable, PodManager, OracleManagerStorage, IOracleManager {
    constructor() {
        _disableInitializers();
    }

    function initialize(address _initialOwner, address _blsApkRegistry, address _aggregatorAddress)
        external
        initializer
    {
        __Ownable_init(_initialOwner);
        __PodManager_init(_blsApkRegistry, _aggregatorAddress);
        confirmBatchId = 0;
    }

    function fillSymbolPriceWithSignature(
        IOraclePod oraclePod,
        OracleBatch calldata oracleBatch,
        IBLSApkRegistry.NonSignerAndSignature memory oracleNonSignerAndSignature
    ) external onlyAggregatorManager onlyPodWhitelistedForFill(address(oraclePod)) {
        (uint256 totalStaking, bytes32 signatoryRecordHash) =
            blsApkRegistry.checkSignatures(oracleBatch.msgHash, oracleBatch.blockNumber, oracleNonSignerAndSignature);

        string memory symbolPrice = oracleBatch.symbolPrice;

        oraclePod.fillSymbolPrice(symbolPrice);

        emit VerifyOracleSig(confirmBatchId++, totalStaking, signatoryRecordHash, symbolPrice);
    }
}
