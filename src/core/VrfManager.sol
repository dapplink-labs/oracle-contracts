// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import "../libraries/SafeCall.sol";
import "../interfaces/IVrfManager.sol";
import "../interfaces/IBLSApkRegistry.sol";
import "../interfaces/IVrfPod.sol";

import "./VrfManagerStorage.sol";

contract VrfManager is OwnableUpgradeable, VrfManagerStorage {
    modifier onlyAggregatorManager() {
        require(
            msg.sender == aggregatorAddress,
            "VrfManager.onlyAggregatorManager: not the aggregator address"
        );
        _;
    }

    modifier onlyPodWhitelistedForFill(IVrfPod vrfPod) {
        require(
            podIsWhitelistedForFill[vrfPod],
            "VrfManager.onlyPodWhitelistedForFill: vrfPod not whitelisted"
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
        blsApkRegistry = IBLSApkRegistry(_blsApkRegistry);
        aggregatorAddress = _aggregatorAddress;
    }

    function registerOperator(string calldata nodeUrl) external {
        require(
            operatorWhitelist[msg.sender],
            "VrfManager.registerOperator: this address have not permission to register "
        );
        blsApkRegistry.registerOperator(msg.sender);
        emit OperatorRegistered(msg.sender, nodeUrl);
    }

    function deRegisterOperator() external {
        require(
            operatorWhitelist[msg.sender],
            "VrfManager.registerOperator: this address have not permission to register "
        );
        blsApkRegistry.deregisterOperator(msg.sender);
        emit OperatorDeRegistered(msg.sender);
    }

    function fillRandWordsWithSignature(
        IVrfPod vrfPod,
        VrfRandomWords calldata vrfRandomWords,
        IBLSApkRegistry.OracleNonSignerAndSignature memory oracleNonSignerAndSignature
    ) external onlyAggregatorManager onlyPodWhitelistedForFill(vrfPod) {
        (
            uint256 totalStaking,
            bytes32 signatoryRecordHash
        ) = blsApkRegistry.checkSignatures(vrfRandomWords.msgHash, vrfRandomWords.blockNumber, oracleNonSignerAndSignature);

        vrfPod.fulfillRandomWords(vrfRandomWords.requestId, vrfRandomWords._randomWords);

        emit VerifyVrfSig(vrfRandomWords.requestId, totalStaking, signatoryRecordHash, vrfRandomWords._randomWords);
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

    function addVrfPodToFillWhitelist(IVrfPod vrfPod) external onlyAggregatorManager {
        podIsWhitelistedForFill[vrfPod] = true;
        emit VrfPodAddedToFillWhitelist(vrfPod);
    }

    function removeVrfPodToFillWhitelist(IVrfPod vrfPod) external onlyAggregatorManager {
        podIsWhitelistedForFill[vrfPod] = false;
        emit VrfPodRemoveToFillWhitelist(vrfPod);
    }
}
