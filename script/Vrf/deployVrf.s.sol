// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {EmptyContract} from "../../src/utils/EmptyContract.sol";
import {BLSApkRegistry} from "../../src/bls/BLSApkRegistry.sol";
import {VrfManager} from "../../src/core/VrfManager.sol";
import {console, Script} from "forge-std/Script.sol";

contract deployVrfScript is Script {
    EmptyContract public emptyContract;

    ProxyAdmin public blsApkRegistryProxyAdmin;
    ProxyAdmin public vrfManagerAdmin;

    BLSApkRegistry public blsApkRegistry;
    BLSApkRegistry public blsApkRegistryImplementation;

    VrfManager public vrfManager;
    VrfManager public vrfManagerImplementation;

    function run() public {
        // owner and relayerManager
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address relayerManagerAddr = vm.envAddress("RELAYER_MANAGER");

        address deployerAddress = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // Deploy BLSApkRegistry proxy and delegate to a empty contract first
        emptyContract = new EmptyContract();
        TransparentUpgradeableProxy proxyBlsApkRegistry = new TransparentUpgradeableProxy(
                address(emptyContract),
                deployerAddress,
                ""
            );
        blsApkRegistry = BLSApkRegistry(address(proxyBlsApkRegistry));
        blsApkRegistryImplementation = new BLSApkRegistry();
        blsApkRegistryProxyAdmin = ProxyAdmin(
            getProxyAdminAddress(address(proxyBlsApkRegistry))
        );

        // Deploy VrfManager proxy and delegate to a empty contract first
        TransparentUpgradeableProxy proxyVrfManager = new TransparentUpgradeableProxy(
                address(emptyContract),
                deployerAddress,
                ""
            );
        vrfManager = VrfManager(address(proxyVrfManager));
        vrfManagerImplementation = new VrfManager();
        vrfManagerAdmin = ProxyAdmin(
            getProxyAdminAddress(address(proxyVrfManager))
        );

        // Upgrade and initialize the implementations
        blsApkRegistryProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(blsApkRegistry)),
            address(blsApkRegistryImplementation),
            abi.encodeWithSelector(
                BLSApkRegistry.initialize.selector,
                deployerAddress,
                relayerManagerAddr,
                address(proxyVrfManager)
            )
        );

        vrfManagerAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(vrfManager)),
            address(vrfManagerImplementation),
            abi.encodeWithSelector(
                VrfManager.initialize.selector,
                deployerAddress,
                proxyBlsApkRegistry,
                deployerAddress
            )
        );

        console.log(
            "deploy proxyBlsApkRegistry:",
            address(proxyBlsApkRegistry)
        );
        console.log("deploy proxyVrfManager:", address(proxyVrfManager));
        string memory path = "deployed_addresses.json";
        string memory data = string(
            abi.encodePacked(
                '{"proxyBlsApkRegistry": "',
                vm.toString(address(proxyBlsApkRegistry)),
                '", ',
                '"proxyVrfManager": "',
                vm.toString(address(proxyVrfManager)),
                '"}'
            )
        );
        vm.writeJson(data, path);
        vm.stopBroadcast();
    }

    function getProxyAdminAddress(
        address proxy
    ) internal view returns (address) {
        address CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
        Vm vm = Vm(CHEATCODE_ADDRESS);

        bytes32 adminSlot = vm.load(proxy, ERC1967Utils.ADMIN_SLOT);
        return address(uint160(uint256(adminSlot)));
    }
}
