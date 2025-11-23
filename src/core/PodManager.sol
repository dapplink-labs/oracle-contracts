// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import "../interfaces/IBLSApkRegistry.sol";

abstract contract PodManager is Initializable, OwnableUpgradeable {
    IBLSApkRegistry public blsApkRegistry;

    address public aggregatorAddress;

    mapping(address => bool) public podIsWhitelistedForFill;
    mapping(address => bool) public operatorWhitelist;

    event OperatorRegistered(address indexed operator, string nodeUrl);
    event OperatorDeRegistered(address operator);
    event PodAddedToFillWhitelist(address pod);
    event PodRemoveToFillWhitelist(address pod);

    modifier onlyAggregatorManager() {
        require(msg.sender == aggregatorAddress, "PodManager.onlyAggregatorManager: not the aggregator address");
        _;
    }

    modifier onlyPodWhitelistedForFill(address pod) {
        require(podIsWhitelistedForFill[pod], "PodManager.onlyPodWhitelistedForFill: pod not whitelisted");
        _;
    }

    function __PodManager_init(address _blsApkRegistry, address _aggregatorAddress) internal {
        blsApkRegistry = IBLSApkRegistry(_blsApkRegistry);
        aggregatorAddress = _aggregatorAddress;
    }

    function registerOperator(string calldata nodeUrl) external {
        require(operatorWhitelist[msg.sender], "PodManager.registerOperator: this address have not permission to register ");
        blsApkRegistry.registerOperator(msg.sender);
        emit OperatorRegistered(msg.sender, nodeUrl);
    }

    function deRegisterOperator() external {
        require(operatorWhitelist[msg.sender], "PodManager.registerOperator: this address have not permission to register ");
        blsApkRegistry.deregisterOperator(msg.sender);
        emit OperatorDeRegistered(msg.sender);
    }

    function addOrRemoveOperatorWhitelist(address operator, bool isAdd) external onlyAggregatorManager {
        require(operator != address(0), "PodManager.addOperatorWhitelist: operator address is zero");
        operatorWhitelist[operator] = isAdd;
    }

    function setAggregatorAddress(address _aggregatorAddress) external onlyOwner {
        require(_aggregatorAddress != address(0), "PodManager.addAggregator: aggregatorAddress address is zero");
        aggregatorAddress = _aggregatorAddress;
    }

    function addPodToFillWhitelist(address pod) external onlyAggregatorManager {
        podIsWhitelistedForFill[pod] = true;
        emit PodAddedToFillWhitelist(pod);
    }

    function removePodToFillWhitelist(address pod) external onlyAggregatorManager {
        podIsWhitelistedForFill[pod] = false;
        emit PodRemoveToFillWhitelist(pod);
    }
}
