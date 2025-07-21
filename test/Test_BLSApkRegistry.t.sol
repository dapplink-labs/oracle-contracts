// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/bls/BLSApkRegistry.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract BLSApkRegistryTest is Test {
    BLSApkRegistry registry;
    ERC1967Proxy proxy;

    address owner = address(0xA1);
    address whiteListManager = address(0xA2);
    address oracleManager = address(0xA3);
    address blsRegister = address(0xA4);

    function setUp() public {
        BLSApkRegistry logic = new BLSApkRegistry();

        bytes memory data = abi.encodeWithSelector(
            BLSApkRegistry.initialize.selector,
            owner,
            whiteListManager,
            oracleManager
        );

        proxy = new ERC1967Proxy(address(logic), data);
        registry = BLSApkRegistry(address(proxy));

        // 添加 blsRegister 到白名单
        vm.prank(whiteListManager);
        registry.addOrRemoveBlsRegisterWhitelist(blsRegister, true);
    }

    function testOnlyWhiteListManagerCanAddWhitelist() public {
        address someAddr = address(0x123);

        // 测试 onlyWhiteListManager
        vm.prank(someAddr);
        vm.expectRevert(
            "BLSApkRegistry.onlyWhiteListManager: caller is not white list address"
        );
        registry.addOrRemoveBlsRegisterWhitelist(address(0xDEAD), true);
    }

    function testWhitelistAndPubkeyRegistration() public {
        // 构造一组bls公钥和签名
        BN254.G1Point memory msgHash = BN254.G1Point({
            X: 21865530482018474585755963423619168960499467353431037262233960899024234433967,
            Y: 3539728706297954110075110532628922806564389507325174160259578565351636992365
        });

        BN254.G1Point memory signature = BN254.G1Point({
            X: 16098063868875928138477990443367166280697131948513748073012692220284750971347,
            Y: 15329843334933716897719702213638165599354107693369133305016255497531224599063
        });

        BN254.G2Point memory pubKeyG2 = BN254.G2Point({
            X: [
                17749938557935567636636221573629998351428902646807247102045274388891431404982,
                4876593892177972657158095557941812406681431312843919154841886886892180250933
            ],
            Y: [
                21414569513416923544024605285721660075805441825497220916794861514170708827362,
                9375354739230872226547817213884458010371979876612785423004996479263944389946
            ]
        });

        BN254.G1Point memory pubKeyG1 = BN254.G1Point({
            X: 20443282814214573593856161370293586240075665004052083344248457337085485625356,
            Y: 13194418538414467055050033907265106142712607841859396823411150580302706299760
        });

        IBLSApkRegistry.PubkeyRegistrationParams memory params = IBLSApkRegistry
            .PubkeyRegistrationParams({
                pubkeyG1: pubKeyG1,
                pubkeyG2: pubKeyG2,
                pubkeyRegistrationSignature: signature
            });

        // 测试注册新的 pubkey 是否成功
        vm.prank(blsRegister);
        bytes32 pubkeyHash = registry.registerBLSPublicKey(
            address(0xBEE),
            params,
            msgHash
        );

        bytes32 readHash = registry.getPubkeyHash(address(0xBEE));
        assertEq(pubkeyHash, readHash);

        // 测试同一个 operator 不能重复注册 pubkey
        vm.prank(blsRegister);
        vm.expectRevert(
            "BLSApkRegistry.registerBLSPublicKey: operator already registered pubkey"
        );
        registry.registerBLSPublicKey(address(0xBEE), params, msgHash);
    }

    function testCannotRegisterWithZeroPubkey() public {
        BN254.G1Point memory zeroG1 = BN254.G1Point(0, 0);
        BN254.G2Point memory pubKeyG2 = BN254.G2Point(
            [uint256(1), 1],
            [uint256(1), 1]
        );

        IBLSApkRegistry.PubkeyRegistrationParams memory params = IBLSApkRegistry
            .PubkeyRegistrationParams({
                pubkeyG1: zeroG1,
                pubkeyG2: pubKeyG2,
                pubkeyRegistrationSignature: zeroG1 // 乱填，为了过编译
            });

        BN254.G1Point memory dummyMsgHash = BN254.G1Point(1, 2); // dummy

        vm.prank(blsRegister);
        vm.expectRevert(
            "BLSApkRegistry.registerBLSPublicKey: cannot register zero pubkey"
        );
        registry.registerBLSPublicKey(address(0xC0DE), params, dummyMsgHash);
    }

    function testOnlyOracleManagerCanRegisterAndDeregister() public {
        // 注册 pubkey
        testWhitelistAndPubkeyRegistration();

        // 非 oracleManager 调用 registerOperator
        vm.prank(address(0x111));
        vm.expectRevert(
            "BLSApkRegistry.onlyOracleManager: caller is not the oracle manager address"
        );
        registry.registerOperator(address(0xBEE));

        // 正常调用
        vm.prank(oracleManager);
        registry.registerOperator(address(0xBEE));

        // 非 oracleManager 调用 deregisterOperator
        vm.prank(address(0x111));
        vm.expectRevert(
            "BLSApkRegistry.onlyOracleManager: caller is not the oracle manager address"
        );
        registry.deregisterOperator(address(0xBEE));

        // 正常调用
        vm.prank(oracleManager);
        registry.deregisterOperator(address(0xBEE));
    }

    function testGetPubkeyRegMessageHash() public view {
        BN254.G1Point memory h = registry.getPubkeyRegMessageHash(
            address(0xBEE)
        );
        assertTrue(h.X != 0 && h.Y != 0, "Message hash should not be zero");
    }

    function testAddAndRemoveBlsRegisterWhitelist() public {
        address tester = address(0xABC);

        vm.prank(whiteListManager);
        registry.addOrRemoveBlsRegisterWhitelist(tester, true);

        vm.prank(whiteListManager);
        registry.addOrRemoveBlsRegisterWhitelist(tester, false);

        BN254.G1Point memory dummy = BN254.G1Point(1, 2);
        BN254.G2Point memory dummyG2 = BN254.G2Point(
            [uint256(11), 21],
            [uint256(11), 41]
        );

        IBLSApkRegistry.PubkeyRegistrationParams memory params = IBLSApkRegistry
            .PubkeyRegistrationParams({
                pubkeyG1: dummy,
                pubkeyG2: dummyG2,
                pubkeyRegistrationSignature: dummy
            });

        vm.prank(tester);
        vm.expectRevert(
            "BLSApkRegistry.registerBLSPublicKey: this address have not permission to register bls key"
        );
        registry.registerBLSPublicKey(address(0xDDD), params, dummy);
    }

    function testTrySignatureAndApkVerification() public view {
        bytes32 msgHash = 0xea83cdcdd06bf61e414054115a551e23133711d0507dcbc07a4bab7dc4581935;

        BN254.G1Point memory signature = BN254.G1Point({
            X: 15194033674394012071916983731564882240605499108993224505298052923469296043512,
            Y: 839159203127434969034550706910060963494405052210926279105817372573420151443
        });

        BN254.G2Point memory pubKeyG2 = BN254.G2Point({
            X: [
                6814450613988925037276906495559354220267038225890288520888556922179861427221,
                11097154366204527428819849175191533397314611771099148982308553889852330000313
            ],
            Y: [
                20799884507081215979545766399242808376431798816319714422985505673585902041706,
                13670248609089265475970799020243713070902269374832615406626549692922451548915
            ]
        });

        BN254.G1Point memory pubKeyG1 = BN254.G1Point({
            X: 21552948824382449035487501529869156133453687741764572533699451941285719913479,
            Y: 18512095983377956955654133313299197583137445769983185530805027107069225976299
        });

        // 4. 调用验证函数
        (bool pairingSuccessful, bool sigValid) = registry
            .trySignatureAndApkVerification(
                msgHash,
                pubKeyG1,
                pubKeyG2,
                signature
            );

        // 5. 断言
        assertTrue(pairingSuccessful, "Pairing failed");
        assertTrue(sigValid, "Signature verification failed");
    }

    function testWhitelistAndPubkeyRegistration01() public {
        // 构造一组bls公钥和签名
        BN254.G1Point memory msgHash = BN254.G1Point({
            X: 18521112453352730579645358173921106118252889045846003563531873900220182176793,
            Y: 12220611982697050695278792018747974293998452760543899595396661668417277566823
        });

        BN254.G1Point memory signature = BN254.G1Point({
            X: 15194033674394012071916983731564882240605499108993224505298052923469296043512,
            Y: 839159203127434969034550706910060963494405052210926279105817372573420151443
        });

        BN254.G2Point memory pubKeyG2 = BN254.G2Point({
            X: [
                6814450613988925037276906495559354220267038225890288520888556922179861427221,
                11097154366204527428819849175191533397314611771099148982308553889852330000313
            ],
            Y: [
                20799884507081215979545766399242808376431798816319714422985505673585902041706,
                13670248609089265475970799020243713070902269374832615406626549692922451548915
            ]
        });

        BN254.G1Point memory pubKeyG1 = BN254.G1Point({
            X: 21552948824382449035487501529869156133453687741764572533699451941285719913479,
            Y: 18512095983377956955654133313299197583137445769983185530805027107069225976299
        });

        IBLSApkRegistry.PubkeyRegistrationParams memory params = IBLSApkRegistry
            .PubkeyRegistrationParams({
                pubkeyG1: pubKeyG1,
                pubkeyG2: pubKeyG2,
                pubkeyRegistrationSignature: signature
            });

        // 测试注册新的 pubkey 是否成功
        vm.prank(blsRegister);
        bytes32 pubkeyHash = registry.registerBLSPublicKey(
            address(0xBEE),
            params,
            msgHash
        );

        bytes32 readHash = registry.getPubkeyHash(address(0xBEE));
        assertEq(pubkeyHash, readHash);

        // 测试同一个 operator 不能重复注册 pubkey
        vm.prank(blsRegister);
        vm.expectRevert(
            "BLSApkRegistry.registerBLSPublicKey: operator already registered pubkey"
        );
        registry.registerBLSPublicKey(address(0xBEE), params, msgHash);
    }
}
