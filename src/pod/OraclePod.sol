// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";

import { OraclePodStorage } from "./OraclePodStorage.sol";


contract OraclePod is Initializable, OwnableUpgradeable, OraclePodStorage {
    constructor() {
        _disableInitializers();
    }

    modifier onlyOracleManager() {
        require (
            msg.sender == oracleManager, "OraclePod.onlyOracleManager: caller is not the oracle manager address"
        );
        _;
    }

    function initialize(address _initialOwner, address _oracleManager) external initializer {
        __Ownable_init(_initialOwner);
        oracleManager = _oracleManager;
    }

    function fillSymbolPrice(string memory price) external onlyOracleManager {
        string memory oldPrice = marketPrice;
        marketPrice = price;
        updateTimestamp = block.timestamp;
        emit MarketPriceUpdated(oldPrice, marketPrice, updateTimestamp);
    }

    function isDataFresh(uint256 maxAge) external view returns (bool) {
        return block.timestamp - updateTimestamp <= maxAge;
    }

    function getSymbolPrice() external view returns (string memory) {
        return marketPrice;
    }

    function setOracleManager(address _oracleManager) external onlyOwner {
        oracleManager = _oracleManager;
        emit OracleManagerUpdate(oracleManager, _oracleManager);
    }
}
