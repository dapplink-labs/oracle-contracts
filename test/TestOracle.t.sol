// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/base/OraclePod.sol";
import "../src/bls/BLSApkRegistry.sol";
import "../src/core/OracleManager.sol";
import "../src/interfaces/IBLSApkRegistry.sol";
import "../src/interfaces/IOracleManager.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract OraclePodTest is Test {
    OraclePod logic;
    OraclePod pod;

    address deployer = address(0xA1);
    address oracleManager = address(0xB1);
    address other = address(0xC1);

    function setUp() public {
        vm.prank(deployer);
        logic = new OraclePod();

        bytes memory initData = abi.encodeWithSelector(
            OraclePod.initialize.selector,
            deployer,
            oracleManager
        );

        vm.prank(deployer);
        ERC1967Proxy proxy = new ERC1967Proxy(address(logic), initData);
        pod = OraclePod(address(proxy));
    }

    function testInitializeSetsOwnerAndOracleManager() public view {
        assertEq(pod.owner(), deployer);
        assertEq(pod.oracleManager(), oracleManager);
    }

    function testOnlyOracleManagerCanFillSymbolPrice() public {
        string memory price = "1000";

        // 非 oracleManager 调用失败
        vm.prank(other);
        vm.expectRevert(
            "OraclePod.onlyOracleManager: caller is not the oracle manager address"
        );
        pod.fillSymbolPrice(price);

        // oracleManager 调用成功
        vm.prank(oracleManager);
        pod.fillSymbolPrice(price);

        assertEq(pod.getSymbolPrice(), price);
    }

    function testFillAndGetPrice() public {
        string memory price = "1234";

        vm.prank(oracleManager);
        pod.fillSymbolPrice(price);

        string memory got = pod.getSymbolPrice();
        assertEq(got, price);
    }
}

contract OracleManagerTest is Test {
    OracleManager oracleManager;
    BLSApkRegistry blsRegistry;
    OraclePod oraclePod;

    address owner = address(0xA1);
    address aggregator = address(0xA2);
    address operator = address(0xA3);
    // address blsRegister = address(0xA4);
    address whiteListManager = address(0xA5);

    function setUp() public {
        // 部署逻辑合约
        OracleManager os_logic = new OracleManager();
        BLSApkRegistry bls_logic = new BLSApkRegistry();
        OraclePod op_logic = new OraclePod();

        // 部署代理合约
        ERC1967Proxy os_proxy = new ERC1967Proxy(address(os_logic), "");
        ERC1967Proxy op_proxy = new ERC1967Proxy(address(op_logic), "");
        ERC1967Proxy bls_proxy = new ERC1967Proxy(address(bls_logic), "");

        // 转换代理合约的接口
        oracleManager = OracleManager(address(os_proxy));
        blsRegistry = BLSApkRegistry(address(bls_proxy));
        oraclePod = OraclePod(address(op_proxy));

        // 初始化合约
        vm.prank(owner);
        oracleManager.initialize(owner, address(blsRegistry), aggregator);
        vm.prank(owner);
        blsRegistry.initialize(owner, whiteListManager, address(oracleManager));
        vm.prank(owner);
        oraclePod.initialize(owner, address(oracleManager));

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

        vm.prank(address(oracleManager));
        blsRegistry.registerOperator(address(operator));
    }

    function test_addOrRemoveOperatorWhitelist() public {
        vm.prank(address(0xE5));
        vm.expectRevert(
            "OracleManager.onlyOracleWhiteListManager: not the aggregator address"
        );
        oracleManager.addOrRemoveOperatorWhitelist(operator, true);

        vm.prank(aggregator);
        oracleManager.addOrRemoveOperatorWhitelist(operator, true);

        vm.prank(aggregator);
        vm.expectRevert(
            "OracleManager.addOperatorWhitelist: operator address is zero"
        );
        oracleManager.addOrRemoveOperatorWhitelist(address(0), true);
    }

    function test_setAggregatorAddress() public {
        vm.prank(address(0xE5));
        vm.expectRevert();
        oracleManager.setAggregatorAddress(aggregator);

        vm.prank(owner);
        oracleManager.setAggregatorAddress(aggregator);

        vm.prank(owner);
        vm.expectRevert(
            "OracleManager.addAggregator: aggregatorAddress address is zero"
        );
        oracleManager.setAggregatorAddress(address(0));
    }

    function test_addOrRemoveOraclePodToFillWhitelist() public {
        vm.prank(address(0xE5));
        vm.expectRevert(
            "OracleManager.onlyOracleWhiteListManager: not the aggregator address"
        );
        oracleManager.addOraclePodToFillWhitelist(oraclePod);

        vm.prank(address(0xE5));
        vm.expectRevert(
            "OracleManager.onlyOracleWhiteListManager: not the aggregator address"
        );
        oracleManager.removeOraclePodToFillWhitelist(oraclePod);

        vm.prank(aggregator);
        oracleManager.addOraclePodToFillWhitelist(oraclePod);
        vm.prank(aggregator);
        oracleManager.removeOraclePodToFillWhitelist(oraclePod);
    }

    function test_RegisterandDegisterOperator() public {
        vm.prank(aggregator);
        oracleManager.addOrRemoveOperatorWhitelist(operator, true);

        vm.prank(address(0xE1));
        vm.expectRevert(
            "OracleManager.registerOperator: this address have not permission to register "
        );
        oracleManager.registerOperator("http://node.url");

        vm.prank(operator);
        oracleManager.registerOperator("http://node.url");

        vm.prank(address(0xE1));
        vm.expectRevert(
            "OracleManager.registerOperator: this address have not permission to register "
        );
        oracleManager.deRegisterOperator();

        vm.prank(operator);
        oracleManager.deRegisterOperator();

        vm.prank(aggregator);
        oracleManager.addOrRemoveOperatorWhitelist(operator, false);

        vm.prank(operator);
        vm.expectRevert(
            "OracleManager.registerOperator: this address have not permission to register "
        );
        oracleManager.registerOperator("http://node.url");
    }

    function testFillSymbolPriceWithSignature() public {
        vm.prank(aggregator);
        oracleManager.addOraclePodToFillWhitelist(oraclePod);

        IBLSApkRegistry.OracleNonSignerAndSignature
            memory noSignerAndSignature = IBLSApkRegistry
                .OracleNonSignerAndSignature({
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
        IOracleManager.OracleBatch memory batch = IOracleManager.OracleBatch({
            msgHash: 0xea83cdcdd06bf61e414054115a551e23133711d0507dcbc07a4bab7dc4581935,
            blockNumber: block.number - 1,
            symbolPrice: "888",
            blockHash: 0xea83cdcdd06bf61e414054115a551e23133711d0507dcbc07a4bab7dc4581935
        });

        vm.prank(aggregator);
        oracleManager.fillSymbolPriceWithSignature(
            oraclePod,
            batch,
            noSignerAndSignature
        );

        assertEq(oraclePod.getSymbolPrice(), "888");
    }

    function testFillSymbolPriceWithoutWhitelistOrAuthority() public {
        IBLSApkRegistry.OracleNonSignerAndSignature
            memory noSignerAndSignature = IBLSApkRegistry
                .OracleNonSignerAndSignature({
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
        IOracleManager.OracleBatch memory batch = IOracleManager.OracleBatch({
            msgHash: 0x3f0a377ba0a4a460ecb616f6507ce0d8cfa3e704025d4fda3ed0c5ca05468728,
            blockNumber: block.number - 1,
            symbolPrice: "888",
            blockHash: 0x3f0a377ba0a4a460ecb616f6507ce0d8cfa3e704025d4fda3ed0c5ca05468728
        });

        vm.prank(address(0xE1));
        vm.expectRevert(
            "OracleManager.onlyOracleWhiteListManager: not the aggregator address"
        );
        oracleManager.fillSymbolPriceWithSignature(
            oraclePod,
            batch,
            noSignerAndSignature
        );

        vm.prank(aggregator);
        vm.expectRevert(
            "OracleManager.onlyPodWhitelistedForFill: oraclePod not whitelisted"
        );
        oracleManager.fillSymbolPriceWithSignature(
            oraclePod,
            batch,
            noSignerAndSignature
        );
    }
}
