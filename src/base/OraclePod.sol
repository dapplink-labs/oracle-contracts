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
        _transferOwnership(_initialOwner);
        oracleManager = _oracleManager;
    }

    function fillSymbolPrice(uint256 price) external onlyOracleManager {
        marketPrice = price;
    }

    function getSymbolPrice() external view returns (uint256) {
        return marketPrice;
    }
}
