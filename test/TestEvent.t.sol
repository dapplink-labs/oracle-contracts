// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/pod/EventPod.sol";
import {EventPodStorage} from "../src/pod/EventPodStorage.sol";
import "../src/bls/BLSApkRegistry.sol";
import "../src/core/EventManager.sol";
import "../src/interfaces/IBLSApkRegistry.sol";
import "../src/interfaces/IEventManager.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract EventPodTest is Test {
    EventPod logic;
    EventPod pod;

    address deployer = address(0xA1);
    address eventManager = address(0xB1);
    address other = address(0xC1);
    uint256 requestId = 888;
    string winner = "pos";

    EventPodStorage.PredictEventInfo predictEventInfo = EventPodStorage.PredictEventInfo({
        requestId: 888,
        eventDescribe: "Team A vs Team B",
        predictPosSide: "Team A wins",
        predictNegSide: "Team B wins",
        winner: "unknown"
    });

    function setUp() public {
        vm.prank(deployer);
        logic = new EventPod();

        bytes memory initData = abi.encodeWithSelector(EventPod.initialize.selector, deployer, eventManager);

        vm.prank(deployer);
        ERC1967Proxy proxy = new ERC1967Proxy(address(logic), initData);
        pod = EventPod(address(proxy));
    }

    function testInitializeSetsOwnerAndEventManager() public view {
        assertEq(pod.owner(), deployer);
        assertEq(pod.eventManager(), eventManager);
    }

    function testOnlyEventManagerCanSubmitEventResult() public {
        // 非 EventManager 调用失败
        vm.prank(other);
        vm.expectRevert("EventPod.onlyEventManager: caller is not the event manager address");
        pod.submitEventResult(requestId, winner);

        // EventManager 调用成功
        vm.prank(eventManager);
        pod.submitEventResult(requestId, winner);

        (string memory posSide, string memory negSide, string memory winner1) = pod.fetchEventResult(requestId);

        // assertEq(posSide, true);
        assertEq(winner1, winner);
    }

    function testOnlyOwnerCanSetEventManager() public {
        vm.prank(eventManager);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, eventManager));
        pod.setEventManager(address(0xD1));

        vm.prank(deployer);
        pod.setEventManager(address(0xD1));
        assertEq(pod.eventManager(), address(0xD1));
    }

    function testCreateEvent() public {
        pod.createEvent(requestId, "Team A vs Team B", "Team A wins", "Team B wins");

        (
            uint256 reqId,
            string memory eventDescribe,
            string memory posSide,
            string memory negSide,
            string memory winner1
        ) = pod.predictEventMapping(requestId);

        (string memory posSide1, string memory negSide1, string memory winner11) = pod.fetchEventResult(requestId);

        assertEq(posSide1, posSide);
        assertEq(negSide1, negSide);
        assertEq(winner11, winner1);
        assertEq(reqId, predictEventInfo.requestId);
        assertEq(eventDescribe, predictEventInfo.eventDescribe);
        assertEq(posSide, predictEventInfo.predictPosSide);
        assertEq(negSide, predictEventInfo.predictNegSide);
        assertEq(winner1, predictEventInfo.winner);
    }
}

contract EventManagerTest is Test {
    EventManager eventManager;
    BLSApkRegistry blsRegistry;
    EventPod eventPod;

    address owner = address(0xA1);
    address aggregator = address(0xA2);
    address operator = address(0xA3);
    // address blsRegister = address(0xA4);
    address whiteListManager = address(0xA5);

    function setUp() public {
        // 部署逻辑合约
        EventManager os_logic = new EventManager();
        BLSApkRegistry bls_logic = new BLSApkRegistry();
        EventPod op_logic = new EventPod();

        // 部署代理合约
        ERC1967Proxy os_proxy = new ERC1967Proxy(address(os_logic), "");
        ERC1967Proxy op_proxy = new ERC1967Proxy(address(op_logic), "");
        ERC1967Proxy bls_proxy = new ERC1967Proxy(address(bls_logic), "");

        // 转换代理合约的接口
        eventManager = EventManager(address(os_proxy));
        blsRegistry = BLSApkRegistry(address(bls_proxy));
        eventPod = EventPod(address(op_proxy));

        // 初始化合约
        vm.prank(owner);
        eventManager.initialize(owner, address(blsRegistry), aggregator);
        vm.prank(owner);
        blsRegistry.initialize(owner, whiteListManager, address(eventManager));
        vm.prank(owner);
        eventPod.initialize(owner, address(eventManager));

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

        IBLSApkRegistry.PubkeyRegistrationParams memory params = IBLSApkRegistry.PubkeyRegistrationParams({
            pubkeyG1: pubKeyG1,
            pubkeyG2: pubKeyG2,
            pubkeyRegistrationSignature: signature
        });

        // operator注册新的 pubkey
        vm.prank(operator);
        bytes32 pubkeyHash = blsRegistry.registerBLSPublicKey(operator, params, msgHash);

        vm.prank(address(eventManager));
        blsRegistry.registerOperator(address(operator));
    }

    function test_addOrRemoveOperatorWhitelist() public {
        vm.prank(address(0xE5));
        vm.expectRevert("PodManager.onlyAggregatorManager: not the aggregator address");
        eventManager.addOrRemoveOperatorWhitelist(operator, true);

        vm.prank(aggregator);
        eventManager.addOrRemoveOperatorWhitelist(operator, true);

        vm.prank(aggregator);
        vm.expectRevert("PodManager.addOperatorWhitelist: operator address is zero");
        eventManager.addOrRemoveOperatorWhitelist(address(0), true);
    }

    function test_setAggregatorAddress() public {
        vm.prank(address(0xE5));
        vm.expectRevert();
        eventManager.setAggregatorAddress(aggregator);

        vm.prank(owner);
        eventManager.setAggregatorAddress(aggregator);

        vm.prank(owner);
        vm.expectRevert("PodManager.addAggregator: aggregatorAddress address is zero");
        eventManager.setAggregatorAddress(address(0));
    }

    function test_addOrRemoveEventPodToFillWhitelist() public {
        vm.prank(address(0xE5));
        vm.expectRevert("PodManager.onlyAggregatorManager: not the aggregator address");
        eventManager.addPodToFillWhitelist(address(eventPod));

        vm.prank(address(0xE5));
        vm.expectRevert("PodManager.onlyAggregatorManager: not the aggregator address");
        eventManager.removePodToFillWhitelist(address(eventPod));

        vm.prank(aggregator);
        eventManager.addPodToFillWhitelist(address(eventPod));
        vm.prank(aggregator);
        eventManager.removePodToFillWhitelist(address(eventPod));
    }

    function test_RegisterandDegisterOperator() public {
        vm.prank(aggregator);
        eventManager.addOrRemoveOperatorWhitelist(operator, true);

        vm.prank(address(0xE1));
        vm.expectRevert("PodManager.registerOperator: this address have not permission to register ");
        eventManager.registerOperator("http://node.url");

        vm.prank(operator);
        vm.expectRevert("BLSApkRegistry.registerBLSPublicKey: Operator have already register");
        eventManager.registerOperator("http://node.url");

        vm.prank(address(0xE1));
        vm.expectRevert("PodManager.registerOperator: this address have not permission to register ");
        eventManager.deRegisterOperator();

        vm.prank(operator);
        eventManager.deRegisterOperator();

        vm.prank(aggregator);
        eventManager.addOrRemoveOperatorWhitelist(operator, false);

        vm.prank(operator);
        vm.expectRevert("PodManager.registerOperator: this address have not permission to register ");
        eventManager.registerOperator("http://node.url");
    }

    function testFillEventResultWithSignature() public {
        vm.prank(aggregator);
        eventManager.addPodToFillWhitelist(address(eventPod));

        IBLSApkRegistry.NonSignerAndSignature memory noSignerAndSignature = IBLSApkRegistry.NonSignerAndSignature({
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

        IEventManager.PredictEvents memory predictEvents = IEventManager.PredictEvents({
            msgHash: 0xea83cdcdd06bf61e414054115a551e23133711d0507dcbc07a4bab7dc4581935,
            blockNumber: block.number - 1,
            requestId: 888,
            blockHash: 0xea83cdcdd06bf61e414054115a551e23133711d0507dcbc07a4bab7dc4581935,
            winner: "pos"
        });

        vm.prank(aggregator);
        eventManager.fillEventResultWithSignature(eventPod, predictEvents, noSignerAndSignature);
        (string memory posSide1, string memory negSide1, string memory winner11) = eventPod.fetchEventResult(888);

        assertEq(winner11, "pos");
    }

    function testFillSymbolPriceWithoutWhitelistOrAuthority() public {
        IBLSApkRegistry.NonSignerAndSignature memory noSignerAndSignature = IBLSApkRegistry.NonSignerAndSignature({
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

        IEventManager.PredictEvents memory predictEvents = IEventManager.PredictEvents({
            msgHash: 0xea83cdcdd06bf61e414054115a551e23133711d0507dcbc07a4bab7dc4581935,
            blockNumber: block.number - 1,
            requestId: 888,
            blockHash: 0xea83cdcdd06bf61e414054115a551e23133711d0507dcbc07a4bab7dc4581935,
            winner: "pos"
        });

        vm.prank(address(0xE1));
        vm.expectRevert("PodManager.onlyAggregatorManager: not the aggregator address");
        eventManager.fillEventResultWithSignature(eventPod, predictEvents, noSignerAndSignature);

        vm.prank(aggregator);
        vm.expectRevert("PodManager.onlyPodWhitelistedForFill: pod not whitelisted");
        eventManager.fillEventResultWithSignature(eventPod, predictEvents, noSignerAndSignature);
    }
}
