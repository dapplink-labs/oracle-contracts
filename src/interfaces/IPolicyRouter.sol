// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPolicyRouter {
    function verifyAll(uint256 policyId, uint256 version, bytes calldata P, bytes calldata sigma, bytes calldata proof, uint256[] calldata pubInputs) external view returns (bool);
}
