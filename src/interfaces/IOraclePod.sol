// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IOraclePod {
    function fillSymbolPrice(uint256 price) external;
    function getSymbolPrice() external view returns (uint256);
}
