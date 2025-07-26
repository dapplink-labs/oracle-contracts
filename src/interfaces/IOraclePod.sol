// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IOraclePod {
    function fillSymbolPrice(string memory price) external;
    function getSymbolPrice() external view returns (string memory);
}
