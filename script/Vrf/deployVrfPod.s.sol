// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import {console, Script} from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {EmptyContract} from "../../src/utils/EmptyContract.sol";
import {VrfPod} from "../../src/pod/VrfPod.sol";
import {VrfManager} from "../../src/core/VrfManager.sol";

import {IVrfManager} from "../../src/interfaces/IVrfManager.sol";
import {IVrfPod} from "../../src/interfaces/IVrfPod.sol";

contract deployVrfPodScript is Script {
    EmptyContract public emptyContract;

    ProxyAdmin public vrfPodAdmin;
    VrfPod public vrfPod;
    VrfPod public vrfPodImplementation;

    function run() public {
        // owner and vrfManager
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address vrfManagerAddr = vm.envAddress("ORACLE_MANAGER");

        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        emptyContract = new EmptyContract();
        TransparentUpgradeableProxy proxyVrfPod =
            new TransparentUpgradeableProxy(address(emptyContract), deployerAddress, "");
        vrfPod = VrfPod(address(proxyVrfPod));
        vrfPodImplementation = new VrfPod();
        vrfPodAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyVrfPod)));

        console.log("vrfPodImplementation===", address(vrfPodImplementation));

        vrfPodAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(vrfPod)),
            address(vrfPodImplementation),
            abi.encodeWithSelector(VrfPod.initialize.selector, deployerAddress, vrfManagerAddr)
        );

        // VrfManager(vrfManagerAddr).addVrfPodToFillWhitelist(proxyVrfPod);

        console.log("deploy proxyVrfPod:", address(proxyVrfPod));
        string memory path = "deployed_addresses.json";
        string memory data = string(
            abi.encodePacked(
                '{"proxyVrfPod": "',
                vm.toString(address(proxyVrfPod)),
                '", ',
                '"vrfPodImplementation": "',
                vm.toString(address(vrfPodImplementation)),
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
