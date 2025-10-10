// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {EmptyContract} from "../../src/utils/EmptyContract.sol";
import {BLSApkRegistry} from "../../src/bls/BLSApkRegistry.sol";
import {EventManager} from "../../src/core/EventManager.sol";
import {console, Script} from "forge-std/Script.sol";

contract deployEventScript is Script {
    EmptyContract public emptyContract;

    ProxyAdmin public blsApkRegistryProxyAdmin;
    ProxyAdmin public eventManagerAdmin;

    BLSApkRegistry public blsApkRegistry;
    BLSApkRegistry public blsApkRegistryImplementation;

    EventManager public eventManager;
    EventManager public eventManagerImplementation;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address relayerManagerAddr = vm.envAddress("RELAYER_MANAGER");

        address deployerAddress = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // Deploy BLSApkRegistry proxy and delegate to a empty contract first
        emptyContract = new EmptyContract();
        TransparentUpgradeableProxy proxyBlsApkRegistry =
            new TransparentUpgradeableProxy(address(emptyContract), deployerAddress, "");
        blsApkRegistry = BLSApkRegistry(address(proxyBlsApkRegistry));
        blsApkRegistryImplementation = new BLSApkRegistry();
        blsApkRegistryProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyBlsApkRegistry)));

        // Deploy EventManager proxy and delegate to a empty contract first
        TransparentUpgradeableProxy proxyEventManager =
            new TransparentUpgradeableProxy(address(emptyContract), deployerAddress, "");
        eventManager = EventManager(address(proxyEventManager));
        eventManagerImplementation = new EventManager();
        eventManagerAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyEventManager)));

        // Upgrade and initialize the implementations
        blsApkRegistryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(blsApkRegistry)),
            address(blsApkRegistryImplementation),
            abi.encodeWithSelector(
                BLSApkRegistry.initialize.selector, deployerAddress, relayerManagerAddr, address(proxyEventManager)
            )
        );

        eventManagerAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(eventManager)),
            address(eventManagerImplementation),
            abi.encodeWithSelector(
                EventManager.initialize.selector, deployerAddress, proxyBlsApkRegistry, deployerAddress
            )
        );

        console.log("deploy proxyBlsApkRegistry:", address(proxyBlsApkRegistry));
        console.log("deploy proxyEventManager:", address(proxyEventManager));
        string memory path = "deployed_addresses.json";
        string memory data = string(
            abi.encodePacked(
                '{"proxyBlsApkRegistry": "',
                vm.toString(address(proxyBlsApkRegistry)),
                '", ',
                '"proxyEventManager": "',
                vm.toString(address(proxyEventManager)),
                '"}'
            )
        );
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
