// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IOracleKYCPod.sol";
import "../interfaces/IVerifier.sol";

contract KYCPolicyRouterStorage {
    // ============================ Events ===============================
    event Verified(uint256 policyId, uint256 version, string zkVerifierDescription, address indexed zkVerifier, address indexed verifierCaller);

    // ============================ Storage ================================

    /// @dev policyId => BLS KYC Pod address
    mapping(uint256 => IOracleKYCPod) public policyToKycPod;
    /// @dev policyId => latest version number
    mapping(uint256 => uint256) public latestPolicyVersion;
    /// @dev zk proof verifier address (optional, to be integrated later)
    mapping(string => IVerifier) public zkVerifiers;

    /// @dev zk proof verifier threshold
    mapping(string => uint256) public zkThresholds;

    uint256[50] private __gap;
}
