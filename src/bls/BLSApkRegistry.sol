// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import "../libraries/BN254.sol";

import "../interfaces/IBLSApkRegistry.sol";

import "./BLSApkRegistryStorage.sol";

contract BLSApkRegistry is
    Initializable,
    OwnableUpgradeable,
    IBLSApkRegistry,
    BLSApkRegistryStorage,
    EIP712
{
    using BN254 for BN254.G1Point;

    uint256 internal constant PAIRING_EQUALITY_CHECK_GAS = 120000;

    modifier onlyWhiteListManager() {
        require(
            msg.sender == whiteListAddress,
            "BLSApkRegistry.onlyWhiteListManager: caller is not white list address"
        );
        _;
    }

    modifier onlyOracleManager() {
        require(
            msg.sender == oracleManager,
            "BLSApkRegistry.onlyOracleManager: caller is not the oracle manager address"
        );
        _;
    }

    constructor() EIP712("BLSApkRegistry", "v0.0.1") {
        _disableInitializers();
    }

    function initialize(
        address _initialOwner,
        address _whiteListAddress,
        address _oracleManager
    ) external initializer {
        __Ownable_init(_initialOwner);
        whiteListAddress = _whiteListAddress;
        oracleManager = _oracleManager;
        _initializeApk();
    }

    function registerOperator(address operator) public onlyOracleManager {
        require(
            operator != address(0),
            "BLSApkRegistry.registerBLSPublicKey: Operator is zero address"
        );

        require(
            !operatorIsRegister[operator],
            "BLSApkRegistry.registerBLSPublicKey: Operator have already register"
        );

        (BN254.G1Point memory pubkey, ) = getRegisteredPubkey(operator);

        _processApkUpdate(pubkey);

        totalNodes += 1;

        operatorIsRegister[operator] = true;

        emit OperatorAdded(operator, operatorToPubkeyHash[operator]);
    }

    function deregisterOperator(address operator) public onlyOracleManager {
        require(
            operatorIsRegister[operator],
            "BLSApkRegistry.registerBLSPublicKey: Operator have already deregister"
        );

        (BN254.G1Point memory pubkey, ) = getRegisteredPubkey(operator);

        _processApkUpdate(pubkey.negate());

        operatorIsRegister[operator] = false;

        totalNodes -= 1;

        emit OperatorRemoved(operator, operatorToPubkeyHash[operator]);
    }

    function registerBLSPublicKey(
        address operator,
        PubkeyRegistrationParams calldata params,
        BN254.G1Point calldata pubkeyRegistrationMessageHash
    ) external returns (bytes32) {
        require(
            msg.sender == operator,
            "BLSApkRegistry.registerBLSPublicKey: this caller is not operator"
        );

        require(
            blsRegisterWhitelist[msg.sender],
            "BLSApkRegistry.registerBLSPublicKey: this address have not permission to register bls key"
        );

        bytes32 pubkeyHash = BN254.hashG1Point(params.pubkeyG1);

        require(
            pubkeyHash != ZERO_PK_HASH,
            "BLSApkRegistry.registerBLSPublicKey: cannot register zero pubkey"
        );
        require(
            operatorToPubkeyHash[operator] == bytes32(0),
            "BLSApkRegistry.registerBLSPublicKey: operator already registered pubkey"
        );

        require(
            pubkeyHashToOperator[pubkeyHash] == address(0),
            "BLSApkRegistry.registerBLSPublicKey: public key already registered"
        );

        uint256 gamma = uint256(
            keccak256(
                abi.encodePacked(
                    params.pubkeyRegistrationSignature.X,
                    params.pubkeyRegistrationSignature.Y,
                    params.pubkeyG1.X,
                    params.pubkeyG1.Y,
                    params.pubkeyG2.X,
                    params.pubkeyG2.Y,
                    pubkeyRegistrationMessageHash.X,
                    pubkeyRegistrationMessageHash.Y
                )
            )
        ) % BN254.FR_MODULUS;

        require(
            BN254.pairing(
                params.pubkeyRegistrationSignature.plus(
                    params.pubkeyG1.scalar_mul(gamma)
                ),
                BN254.negGeneratorG2(),
                pubkeyRegistrationMessageHash.plus(
                    BN254.generatorG1().scalar_mul(gamma)
                ),
                params.pubkeyG2
            ),
            "BLSApkRegistry.registerBLSPublicKey: either the G1 signature is wrong, or G1 and G2 private key do not match"
        );

        operatorToPubkey[operator] = params.pubkeyG1;
        operatorToPubkeyHash[operator] = pubkeyHash;
        pubkeyHashToOperator[pubkeyHash] = operator;

        emit NewPubkeyRegistration(operator, params.pubkeyG1, params.pubkeyG2);

        return pubkeyHash;
    }

    function checkSignatures(
        bytes32 msgHash,
        uint256 referenceBlockNumber,
        NonSignerAndSignature memory params
    ) public view returns (uint256, bytes32) {
        require(
            referenceBlockNumber < uint32(block.number),
            "BLSSignatureChecker.checkSignatures: invalid reference block"
        );

        uint256 nonSingerNode = params.nonSignerPubkeys.length;
        uint256 thresholdNodes = (totalNodes * 2) / 3;

        require(
            totalNodes - nonSingerNode >= thresholdNodes,
            "BLSSignatureChecker.checkSignatures: sign node less than threshold node"
        );

        BN254.G1Point memory signerApk = BN254.G1Point(0, 0);
        bytes32[] memory nonSignersPubkeyHashes;
        if (params.nonSignerPubkeys.length > 0) {
            nonSignersPubkeyHashes = new bytes32[](
                params.nonSignerPubkeys.length
            );
            for (uint256 j = 0; j < params.nonSignerPubkeys.length; j++) {
                nonSignersPubkeyHashes[j] = params
                    .nonSignerPubkeys[j]
                    .hashG1Point();
                signerApk = currentApk.plus(
                    params.nonSignerPubkeys[j].negate()
                );
            }
        } else {
            signerApk = currentApk;
        }
        (
            bool pairingSuccessful,
            bool signatureIsValid
        ) = trySignatureAndApkVerification(
                msgHash,
                signerApk,
                params.apkG2,
                params.sigma
            );
        require(
            pairingSuccessful,
            "BLSSignatureChecker.checkSignatures: pairing precompile call failed"
        );
        require(
            signatureIsValid,
            "BLSSignatureChecker.checkSignatures: signature is invalid"
        );

        bytes32 signatoryRecordHash = keccak256(
            abi.encodePacked(referenceBlockNumber, nonSignersPubkeyHashes)
        );

        return (params.totalStake, signatoryRecordHash);
    }

    function addOrRemoveBlsRegisterWhitelist(
        address register,
        bool isAdd
    ) external onlyWhiteListManager {
        require(
            register != address(0),
            "BLSApkRegistry.addOrRemoverBlsRegisterWhitelist: operator address is zero"
        );
        blsRegisterWhitelist[register] = isAdd;
    }

    function trySignatureAndApkVerification(
        bytes32 msgHash,
        BN254.G1Point memory apk,
        BN254.G2Point memory apkG2,
        BN254.G1Point memory sigma
    ) public view returns (bool pairingSuccessful, bool siganatureIsValid) {
        uint256 gamma = uint256(
            keccak256(
                abi.encodePacked(
                    msgHash,
                    apk.X,
                    apk.Y,
                    apkG2.X[0],
                    apkG2.X[1],
                    apkG2.Y[0],
                    apkG2.Y[1],
                    sigma.X,
                    sigma.Y
                )
            )
        ) % BN254.FR_MODULUS;
        (pairingSuccessful, siganatureIsValid) = BN254.safePairing(
            sigma.plus(apk.scalar_mul(gamma)),
            BN254.negGeneratorG2(),
            BN254.hashToG1(msgHash).plus(BN254.generatorG1().scalar_mul(gamma)),
            apkG2,
            PAIRING_EQUALITY_CHECK_GAS
        );
    }

    function _processApkUpdate(BN254.G1Point memory point) internal {
        BN254.G1Point memory newApk;

        uint256 historyLength = apkHistory.length;
        require(
            historyLength != 0,
            "BLSApkRegistry._processApkUpdate: quorum does not exist"
        );

        newApk = currentApk.plus(point);
        currentApk = newApk;

        bytes24 newApkHash = bytes24(BN254.hashG1Point(newApk));

        ApkUpdate storage lastUpdate = apkHistory[historyLength - 1];
        if (lastUpdate.updateBlockNumber == uint32(block.number)) {
            lastUpdate.apkHash = newApkHash;
        } else {
            lastUpdate.nextUpdateBlockNumber = uint32(block.number);
            apkHistory.push(
                ApkUpdate({
                    apkHash: newApkHash,
                    updateBlockNumber: uint32(block.number),
                    nextUpdateBlockNumber: 0
                })
            );
        }
    }

    function getRegisteredPubkey(
        address operator
    ) public view returns (BN254.G1Point memory, bytes32) {
        BN254.G1Point memory pubkey = operatorToPubkey[operator];
        bytes32 pubkeyHash = operatorToPubkeyHash[operator];

        require(
            pubkeyHash != bytes32(0),
            "BLSApkRegistry.getRegisteredPubkey: operator is not registered"
        );

        return (pubkey, pubkeyHash);
    }

    function getPubkeyRegMessageHash(
        address operator
    ) public view returns (BN254.G1Point memory) {
        return
            BN254.hashToG1(
                _hashTypedDataV4(
                    keccak256(
                        abi.encode(PUBKEY_REGISTRATION_TYPEHASH, operator)
                    )
                )
            );
    }

    function _initializeApk() internal {
        require(
            apkHistory.length == 0,
            "BLSApkRegistry.initializeApk: apk already exists"
        );

        apkHistory.push(
            ApkUpdate({
                apkHash: bytes24(0),
                updateBlockNumber: uint32(block.number),
                nextUpdateBlockNumber: 0
            })
        );
    }

    function getPubkeyHash(address operator) public view returns (bytes32) {
        return operatorToPubkeyHash[operator];
    }
}
