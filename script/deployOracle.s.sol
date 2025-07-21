// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { EmptyContract } from "../src/utils/EmptyContract.sol";
import { BLSApkRegistry } from "../src/bls/BLSApkRegistry.sol";
import { OracleManager } from "../src/core/OracleManager.sol";
import { console, Script } from "forge-std/Script.sol";

contract deployOracleScript is Script {
    EmptyContract public emptyContract;

    ProxyAdmin public blsApkRegistryProxyAdmin;
    ProxyAdmin public oracleManagerAdmin;

    BLSApkRegistry public blsApkRegistry;
    BLSApkRegistry public blsApkRegistryImplementation;

    OracleManager public oracleManager;
    OracleManager public oracleManagerImplementation;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address relayerManagerAddr =  vm.envAddress("RELAYER_MANAGER");

        address deployerAddress = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        emptyContract = new EmptyContract();
        TransparentUpgradeableProxy proxyBlsApkRegistry = new TransparentUpgradeableProxy(address(emptyContract), deployerAddress, "");
        blsApkRegistry = BLSApkRegistry(address(proxyBlsApkRegistry));
        blsApkRegistryImplementation = new BLSApkRegistry();
        blsApkRegistryProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyBlsApkRegistry)));


        TransparentUpgradeableProxy proxyOracleManager = new TransparentUpgradeableProxy(address(emptyContract), deployerAddress, "");
        oracleManager = OracleManager(address(proxyOracleManager));
        oracleManagerImplementation = new OracleManager();
        oracleManagerAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyOracleManager)));


        blsApkRegistryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(blsApkRegistry)),
            address(blsApkRegistryImplementation),
            abi.encodeWithSelector(
                BLSApkRegistry.initialize.selector,
                deployerAddress,
                relayerManagerAddr,
                proxyOracleManager
            )
        );

        oracleManagerAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(oracleManager)),
            address(oracleManagerImplementation),
            abi.encodeWithSelector(
                OracleManager.initialize.selector,
                deployerAddress,
                proxyBlsApkRegistry,
                deployerAddress
            )
        );

        console.log("deploy proxyBlsApkRegistry:", address(proxyBlsApkRegistry));
        console.log("deploy proxyOracleManager:", address(proxyOracleManager));
        string memory path = "deployed_addresses.json";
        string memory data = string(abi.encodePacked(
            '{"proxyBlsApkRegistry": "', vm.toString(address(proxyBlsApkRegistry)), '", ',
            '"proxyOracleManager": "', vm.toString(address(proxyOracleManager)), '"}'
        ));
        vm.writeJson(data, path);
        vm.stopBroadcast();
    }

    function getProxyAdminAddress(address proxy) internal view returns (address) {
        address CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
        Vm vm = Vm(CHEATCODE_ADDRESS);

        bytes32 adminSlot = vm.load(proxy, ERC1967Utils.ADMIN_SLOT);
        return address(uint160(uint256(adminSlot)));
    }
}
