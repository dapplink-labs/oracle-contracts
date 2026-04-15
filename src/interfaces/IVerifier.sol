// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVerifier {
    function verifyProof(uint256[8] calldata proof, uint256[4] calldata pubInputs) external view returns (bool);
}
