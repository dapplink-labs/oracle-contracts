// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IOracleKYCPod.sol";
import "../interfaces/IVerifier.sol";

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "../libraries/BN254.sol";
import "./KYCPolicyRouterStorage.sol";

/// @title KYCPolicyRouter
/// @notice Upper-layer design, Layer 3: zkID Policy Verifier & Oracle Router
///         - Route to the corresponding Oracle KYC Pod based on different policyId
///         - Call OracleSigVerifier.verify() to verify BLS signatures
///         - (Reserved) Call zk proof verifier to verify zero-knowledge proofs
contract KYCPolicyRouter is Initializable, OwnableUpgradeable, KYCPolicyRouterStorage {
    // ============================ Functions ==============================

    /// @notice Initialize the contract
    function initialize(address _initialOwner) public initializer {
        __Ownable_init(_initialOwner);
    }

    /// @dev Set zkVerifier; different verifiers can be used for different policies,
    ///      such as checking age, nationality, etc.
    /// @dev Can also be set to address(0) to skip zk proof verification
    /// @param description Verifier description, e.g. "age_over_18"
    /// @param _verifier   Verifier contract address
    function setZkVerifier(string memory description, address _verifier) external onlyOwner {
        zkVerifiers[description] = IVerifier(_verifier);
    }

    /// @dev Set zkVerifier threshold
    /// @param description Verifier description, e.g. "age_over_18"
    /// @param threshold   Threshold value for the verifier
    function setZkThreshold(string memory description, uint256 threshold) external onlyOwner {
        zkThresholds[description] = threshold;
    }

    /// @dev Bind an Oracle KYC Pod to a specific policy
    /// @dev Also acts as registration for the Oracle KYC Pod
    /// @param policyId Business policy ID
    /// @param kycPod   Oracle KYC Pod contract address
    function setPolicykycPod(uint256 policyId, address kycPod) external onlyOwner {
        policyToKycPod[policyId] = IOracleKYCPod(kycPod);
    }

    /// @dev Update the latest version number of a specific policy
    /// @param policyId Business policy ID
    /// @param version  Latest version
    function setLatestPolicyVersion(uint256 policyId, uint256 version) external onlyOwner {
        latestPolicyVersion[policyId] = version;
    }

    // =============== Verification Logic  ===============

    /// @notice Full pipeline for BLS + ZK verification
    /// @param policyId    Business policy ID
    /// @param version     Policy version
    /// @param proof       zk proof (placeholder)
    function verifyAll(uint256 policyId, uint256 version, uint256[8] calldata proof, string memory zkVerifierDescription) external returns (bool) {
        // 1. Find the corresponding Oracle KYC Pod by policyId
        require(version == latestPolicyVersion[policyId], "PolicyRouter: policy version mismatch"); // Must match the Oracle's latest version
        IOracleKYCPod kycPod = policyToKycPod[policyId];
        require(address(kycPod) != address(0), "PolicyRouter: kycPod not set");

        // 2. First perform Oracle KYC verification
        require(kycPod.isVerified(msg.sender), "PolicyRouter: user not verified");
        uint256 commitment = kycPod.getCommitment(msg.sender);

        // 3. Verify zk proof (requires zk proof to pass)
        IVerifier zkVerifier = zkVerifiers[zkVerifierDescription];
        uint256 threshold = zkThresholds[zkVerifierDescription];
        require(address(zkVerifier) != address(0), "PolicyRouter: zk verifier not set");

        _verify(zkVerifier, proof, policyId, version, commitment, threshold);
        emit Verified(policyId, version, zkVerifierDescription, address(zkVerifier), msg.sender);
        return true;
    }

    function _verify(IVerifier zkVerifier, uint256[8] calldata proof, uint256 policyId, uint256 version, uint256 commitment, uint256 threshold) internal view {
        uint256[4] memory pubInputs;
        pubInputs[0] = policyId;
        pubInputs[1] = version;
        pubInputs[2] = commitment;
        pubInputs[3] = threshold;

        require(zkVerifier.verifyProof(proof, pubInputs), "PolicyRouter: zk proof invalid");
    }
}
