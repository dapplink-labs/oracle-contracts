// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IOracleKYCPod {
    struct Record {
        uint256 commitment; // Poseidon(m, did, policy_id, version)
        bool verified; // Whether verification has succeeded
    }

    event KYCRecorded(address indexed user, uint256 commitment);

    /// @notice Record the KYC verification result (callable only by the manager contract)
    function recordVerification(address user, bool isVerified, uint256 commitment) external;

    /// @notice Check whether a given DID has been verified
    function isVerified(address user) external view returns (bool);

    /// @notice Query the full record
    function getRecord(address user) external view returns (Record memory);

    function getCommitment(address user) external view returns (uint256);
}
