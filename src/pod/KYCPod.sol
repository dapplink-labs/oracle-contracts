// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "./KYCPodStorage.sol";

/**
 * @title KYCPod
 * @notice Stores each user's KYC verification result and commitment value C.
 * @dev Uses the user address as the key; the DID is not exposed on-chain.
 */
contract KYCPod is Initializable, OwnableUpgradeable, KYCPodStorage {
    function initialize(address _initialOwner) external initializer {
        __Ownable_init(_initialOwner);
    }

    /**
     * @notice Record a user's KYC verification result
     * @dev Only KYCManager (Owner) can call this
     *
     * Commitment = Poseidon(m, r, did, policy_id, version)
     *   m: user's private KYC plaintext (such as age, nationality)
     *   r: random salt (or derived from did)
     *   did: private identity identifier
     *   policy_id / version: policy context
     */
    function recordVerification(address user, bool verified, uint256 commitment) external onlyOwner {
        Record storage rec = kycRecords[user];
        rec.commitment = commitment;

        rec.verified = verified;
        emit KYCRecorded(user, commitment);
    }

    function isVerified(address user) external view returns (bool) {
        return kycRecords[user].verified;
    }

    function getRecord(address user) external view returns (Record memory) {
        return kycRecords[user];
    }

    function getCommitment(address user) external view returns (uint256) {
        return kycRecords[user].commitment;
    }
}
