// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import "../libraries/SafeCall.sol";
import "../interfaces/IOracleManager.sol";
import "../interfaces/IBLSApkRegistry.sol";
import "../interfaces/IOraclePod.sol";

import "./OracleManagerStorage.sol";

contract OracleManager is OwnableUpgradeable, OracleManagerStorage, IOracleManager {
    modifier onlyAggregatorManager() {
        require(
            msg.sender == aggregatorAddress,
            "OracleManager.onlyOracleWhiteListManager: not the aggregator address"
        );
        _;
    }

    modifier onlyPodWhitelistedForFill(IOraclePod oraclePod) {
        require(
            podIsWhitelistedForFill[oraclePod],
            "OracleManager.onlyPodWhitelistedForFill: oraclePod not whitelisted"
        );
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _initialOwner,
        address _blsApkRegistry,
        address _aggregatorAddress
    ) external initializer {
        __Ownable_init(_initialOwner);
        _transferOwnership(_initialOwner);
        blsApkRegistry = IBLSApkRegistry(_blsApkRegistry);
        aggregatorAddress = _aggregatorAddress;
        confirmBatchId = 0;
    }

    function registerOperator(string calldata nodeUrl) external {
        require(
            operatorWhitelist[msg.sender],
            "OracleManager.registerOperator: this address have not permission to register "
        );
        blsApkRegistry.registerOperator(msg.sender);
        emit OperatorRegistered(msg.sender, nodeUrl);
    }

    function deRegisterOperator() external {
        require(
            operatorWhitelist[msg.sender],
            "OracleManager.registerOperator: this address have not permission to register "
        );
        blsApkRegistry.deregisterOperator(msg.sender);
        emit OperatorDeRegistered(msg.sender);
    }

    function fillSymbolPriceWithSignature(
        IOraclePod oraclePod,
        OracleBatch calldata oracleBatch,
        IBLSApkRegistry.OracleNonSignerAndSignature memory oracleNonSignerAndSignature
    ) external onlyAggregatorManager onlyPodWhitelistedForFill(oraclePod) {
        (
            uint256 totalStaking,
            bytes32 signatoryRecordHash
        ) = blsApkRegistry.checkSignatures(oracleBatch.msgHash, oracleBatch.blockNumber, oracleNonSignerAndSignature);

        uint256 symbolPrice = oracleBatch.symbolPrice;

        oraclePod.fillSymbolPrice(symbolPrice);

        emit VerifyOracleSig(confirmBatchId++, totalStaking, signatoryRecordHash, symbolPrice);
    }

    function addOrRemoveOperatorWhitelist(address operator, bool isAdd) external onlyAggregatorManager {
        require(
            operator != address (0),
            "OracleManager.addOperatorWhitelist: operator address is zero"
        );
        operatorWhitelist[operator] = isAdd;
    }

    function setAggregatorAddress(address _aggregatorAddress) external onlyOwner {
        require(
            _aggregatorAddress != address (0),
            "OracleManager.addAggregator: aggregatorAddress address is zero"
        );
        aggregatorAddress = _aggregatorAddress;
    }

    function addOraclePodToFillWhitelist(IOraclePod oraclePod) external onlyAggregatorManager {
        podIsWhitelistedForFill[oraclePod] = true;
        emit OraclePodAddedToFillWhitelist(oraclePod);
    }

    function removeOraclePodToFillWhitelist(IOraclePod oraclePod) external onlyAggregatorManager {
        podIsWhitelistedForFill[oraclePod] = false;
        emit OraclePodRemoveToFillWhitelist(oraclePod);
    }
}
