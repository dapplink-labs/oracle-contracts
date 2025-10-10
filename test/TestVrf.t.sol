// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/pod/VrfPod.sol";
import "../src/bls/BLSApkRegistry.sol";
import "../src/core/VrfManager.sol";
import "../src/interfaces/IBLSApkRegistry.sol";
import "../src/interfaces/IVrfManager.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract VrfPodTest is Test {
    VrfPod logic;
    VrfPod pod;

    address deployer = address(0xA1);
    address vrfManager = address(0xB1);
    address other = address(0xC1);

    uint256 requestId = 1;
    uint256[] randomWords = [uint256(123), uint256(456), uint256(789)];

    function setUp() public {
        vm.prank(deployer);
        logic = new VrfPod();

        bytes memory initData = abi.encodeWithSelector(
            VrfPod.initialize.selector,
            deployer,
            vrfManager
        );

        vm.prank(deployer);
        ERC1967Proxy proxy = new ERC1967Proxy(address(logic), initData);
        pod = VrfPod(address(proxy));
    }

    function testInitializeSetsOwnerAndVrfManager() public view {
        assertEq(pod.owner(), deployer);
        assertEq(pod.vrfManager(), vrfManager);
    }

    function testOnlyVrfManagerCanFulfillRandomWords() public {
        // 非 VrfManager 调用失败
        vm.prank(other);
        vm.expectRevert("DappLinkVRF.onlyVrfManager can call this function");
        pod.fulfillRandomWords(requestId, randomWords);

        // VrfManager 调用成功
        vm.prank(vrfManager);
        pod.fulfillRandomWords(requestId, randomWords);

        (bool fulfilled, uint256[] memory words) = pod.getRandomWordsWithStatus(
            requestId
        );

        assertEq(fulfilled, true);
        assertEq(words, randomWords);
    }

    function testOnlyOwnerCanSetVrfManager() public {
        vm.prank(vrfManager);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                vrfManager
            )
        );
        pod.setVrfManager(address(0xD1));

        vm.prank(deployer);
        pod.setVrfManager(address(0xD1));
        assertEq(pod.vrfManager(), address(0xD1));
    }

    function testRequestRandomWords() public {
        pod.requestRandomWords(requestId, 3);

        (bool fulfilled, uint256[] memory words) = pod.getRandomWordsWithStatus(
            requestId
        );

        assertEq(fulfilled, false);
        assertEq(words.length, 0);
    }
}

contract VrfManagerTest is Test {
    VrfManager vrfManager;
    BLSApkRegistry blsRegistry;
    VrfPod vrfPod;

    address owner = address(0xA1);
    address aggregator = address(0xA2);
    address operator = address(0xA3);
    // address blsRegister = address(0xA4);
    address whiteListManager = address(0xA5);

    function setUp() public {
        // 部署逻辑合约
        VrfManager os_logic = new VrfManager();
        BLSApkRegistry bls_logic = new BLSApkRegistry();
        VrfPod op_logic = new VrfPod();

        // 部署代理合约
        ERC1967Proxy os_proxy = new ERC1967Proxy(address(os_logic), "");
        ERC1967Proxy op_proxy = new ERC1967Proxy(address(op_logic), "");
        ERC1967Proxy bls_proxy = new ERC1967Proxy(address(bls_logic), "");

        // 转换代理合约的接口
        vrfManager = VrfManager(address(os_proxy));
        blsRegistry = BLSApkRegistry(address(bls_proxy));
        vrfPod = VrfPod(address(op_proxy));

        // 初始化合约
        vm.prank(owner);
        vrfManager.initialize(owner, address(blsRegistry), aggregator);
        vm.prank(owner);
        blsRegistry.initialize(owner, whiteListManager, address(vrfManager));
        vm.prank(owner);
        vrfPod.initialize(owner, address(vrfManager));

        // 添加 operator 到白名单
        vm.prank(whiteListManager);
        blsRegistry.addOrRemoveBlsRegisterWhitelist(operator, true);

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

        // operator注册新的 pubkey
        vm.prank(operator);
        bytes32 pubkeyHash = blsRegistry.registerBLSPublicKey(
            operator,
            params,
            msgHash
        );

        vm.prank(address(vrfManager));
        blsRegistry.registerOperator(address(operator));
    }

    function test_addOrRemoveOperatorWhitelist() public {
        vm.prank(address(0xE5));
        vm.expectRevert(
            "PodManager.onlyAggregatorManager: not the aggregator address"
        );
        vrfManager.addOrRemoveOperatorWhitelist(operator, true);

        vm.prank(aggregator);
        vrfManager.addOrRemoveOperatorWhitelist(operator, true);

        vm.prank(aggregator);
        vm.expectRevert(
            "PodManager.addOperatorWhitelist: operator address is zero"
        );
        vrfManager.addOrRemoveOperatorWhitelist(address(0), true);
    }

    function test_setAggregatorAddress() public {
        vm.prank(address(0xE5));
        vm.expectRevert();
        vrfManager.setAggregatorAddress(aggregator);

        vm.prank(owner);
        vrfManager.setAggregatorAddress(aggregator);

        vm.prank(owner);
        vm.expectRevert(
            "PodManager.addAggregator: aggregatorAddress address is zero"
        );
        vrfManager.setAggregatorAddress(address(0));
    }

    function test_addOrRemoveVrfPodToFillWhitelist() public {
        vm.prank(address(0xE5));
        vm.expectRevert(
            "PodManager.onlyAggregatorManager: not the aggregator address"
        );
        vrfManager.addPodToFillWhitelist(address(vrfPod));

        vm.prank(address(0xE5));
        vm.expectRevert(
            "PodManager.onlyAggregatorManager: not the aggregator address"
        );
        vrfManager.removePodToFillWhitelist(address(vrfPod));

        vm.prank(aggregator);
        vrfManager.addPodToFillWhitelist(address(vrfPod));
        vm.prank(aggregator);
        vrfManager.removePodToFillWhitelist(address(vrfPod));
    }

    function test_RegisterandDegisterOperator() public {
        vm.prank(aggregator);
        vrfManager.addOrRemoveOperatorWhitelist(operator, true);

        vm.prank(address(0xE1));
        vm.expectRevert(
            "PodManager.registerOperator: this address have not permission to register "
        );
        vrfManager.registerOperator("http://node.url");

        vm.prank(operator);
        vm.expectRevert(
            "BLSApkRegistry.registerBLSPublicKey: Operator have already register"
        );
        vrfManager.registerOperator("http://node.url");

        vm.prank(address(0xE1));
        vm.expectRevert(
            "PodManager.registerOperator: this address have not permission to register "
        );
        vrfManager.deRegisterOperator();

        vm.prank(operator);
        vrfManager.deRegisterOperator();

        vm.prank(aggregator);
        vrfManager.addOrRemoveOperatorWhitelist(operator, false);

        vm.prank(operator);
        vm.expectRevert(
            "PodManager.registerOperator: this address have not permission to register "
        );
        vrfManager.registerOperator("http://node.url");
    }

    function testFillRandWordsWithSignature() public {
        vm.prank(aggregator);
        vrfManager.addPodToFillWhitelist(address(vrfPod));

        IBLSApkRegistry.NonSignerAndSignature
            memory noSignerAndSignature = IBLSApkRegistry
                .NonSignerAndSignature({
                    nonSignerPubkeys: new BN254.G1Point[](0),
                    apkG2: BN254.G2Point({
                        X: [
                            6814450613988925037276906495559354220267038225890288520888556922179861427221,
                            11097154366204527428819849175191533397314611771099148982308553889852330000313
                        ],
                        Y: [
                            20799884507081215979545766399242808376431798816319714422985505673585902041706,
                            13670248609089265475970799020243713070902269374832615406626549692922451548915
                        ]
                    }),
                    sigma: BN254.G1Point({
                        X: 15194033674394012071916983731564882240605499108993224505298052923469296043512,
                        Y: 839159203127434969034550706910060963494405052210926279105817372573420151443
                    }),
                    totalStake: 888
                });

        uint256[] memory arr = new uint256[](1);
        arr[0] = 43;
        IVrfManager.VrfRandomWords memory randomWords = IVrfManager
            .VrfRandomWords({
                msgHash: 0xea83cdcdd06bf61e414054115a551e23133711d0507dcbc07a4bab7dc4581935,
                blockNumber: block.number - 1,
                requestId: 888,
                blockHash: 0xea83cdcdd06bf61e414054115a551e23133711d0507dcbc07a4bab7dc4581935,
                _randomWords: arr
            });

        vm.prank(aggregator);
        vrfManager.fillRandWordsWithSignature(
            vrfPod,
            randomWords,
            noSignerAndSignature
        );
        (bool fulfilled, uint256[] memory words) = vrfPod
            .getRandomWordsWithStatus(888);

        assertEq(fulfilled, true);
        assertEq(words, arr);
    }

    function testFillSymbolPriceWithoutWhitelistOrAuthority() public {
        IBLSApkRegistry.NonSignerAndSignature
            memory noSignerAndSignature = IBLSApkRegistry
                .NonSignerAndSignature({
                    nonSignerPubkeys: new BN254.G1Point[](0),
                    apkG2: BN254.G2Point({
                        X: [
                            19552866287184064427995511006223057169680536518603642638640105365054342788017,
                            19912786774583403697047133238687463296134677575618298225286334615015816916116
                        ],
                        Y: [
                            2970994197396269892653525920024039859830728356246595152296683945713431676344,
                            18119535013136907197909765078809655896321461883746857179927989514870514777799
                        ]
                    }),
                    sigma: BN254.G1Point({
                        X: 15723530600246276940894768360396890326319571568844052976858037242805072605559,
                        Y: 11650315804718231422577338154702931145725917843701074925949828011449296498014
                    }),
                    totalStake: 888
                });

        uint256[] memory arr = new uint256[](1);
        arr[0] = 43;
        IVrfManager.VrfRandomWords memory randomWords = IVrfManager
            .VrfRandomWords({
                msgHash: 0xea83cdcdd06bf61e414054115a551e23133711d0507dcbc07a4bab7dc4581935,
                blockNumber: block.number - 1,
                requestId: 888,
                blockHash: 0xea83cdcdd06bf61e414054115a551e23133711d0507dcbc07a4bab7dc4581935,
                _randomWords: arr
            });

        vm.prank(address(0xE1));
        vm.expectRevert(
            "PodManager.onlyAggregatorManager: not the aggregator address"
        );
        vrfManager.fillRandWordsWithSignature(
            vrfPod,
            randomWords,
            noSignerAndSignature
        );

        vm.prank(aggregator);
        vm.expectRevert(
            "PodManager.onlyPodWhitelistedForFill: pod not whitelisted"
        );
        vrfManager.fillRandWordsWithSignature(
            vrfPod,
            randomWords,
            noSignerAndSignature
        );
    }
}
