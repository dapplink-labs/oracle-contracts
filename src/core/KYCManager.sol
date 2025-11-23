// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "../interfaces/IBLSApkRegistry.sol";
import "../interfaces/IKYCPod.sol";
import "./PodManager.sol";
import "./KYCManagerStorage.sol";

/**
 * @title KYCManager
 * @notice Deployed by the Oracle side, used to verify aggregated signatures
 *         and register results in the Oracle Pod contract.
 * @dev Note: DID is no longer used as the index; the user address is used instead.
 */
contract KYCManager is Initializable, OwnableUpgradeable, PodManager, KYCManagerStorage {
    constructor() {
        _disableInitializers();
    }

    function initialize(address _initialOwner, address _blsApkRegistry, address _aggregatorManager) external initializer {
        __Ownable_init(_initialOwner);
        __PodManager_init(_blsApkRegistry, _aggregatorManager);
    }

    /**
     * @notice Oracle nodes submit KYC verification results and register the commitment
     * @param oraclePod Oracle KYC Pod contract address
     * @param params KYC verification parameters (user, commitment, msgHash, refBlock)
     * @param oracleNonSignerAndSignature Aggregated signature struct
     */
    function verifyAndPodKYC(IKYCPod oraclePod, KYCVerifyParams calldata params, IBLSApkRegistry.NonSignerAndSignature memory oracleNonSignerAndSignature) external onlyAggregatorManager {
        // Verify the Oracle aggregated signature
        (uint256 totalStake, bytes32 signPodHash) = blsApkRegistry.checkSignatures(params.msgHash, params.refBlock, oracleNonSignerAndSignature);

        // Persist state
        oraclePod.recordVerification(params.user, params.isVerified, params.commitment);

        emit KYCVerified(params.user, params.commitment, signPodHash, totalStake);
    }
}
