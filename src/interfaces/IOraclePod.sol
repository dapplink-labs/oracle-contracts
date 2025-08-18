// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IOraclePod {
    event MarketPriceUpdated(
        string oldPrice ,
        string price,
        uint256 timestamp
    );

<<<<<<< HEAD
=======
    event OracleManagerUpdate(
        address oldManagerAddress ,
        address newManagerAddress
    );

>>>>>>> feature/audit-fix
    function fillSymbolPrice(string memory price) external;
    function isDataFresh(uint256 maxAge) external view returns (bool);
    function getSymbolPrice() external view returns (string memory);
}
