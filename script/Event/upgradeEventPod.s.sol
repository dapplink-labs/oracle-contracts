// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import {console, Script} from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {EmptyContract} from "../../src/utils/EmptyContract.sol";
import {EventPod} from "../../src/pod/EventPod.sol";
import {IEventManager} from "../../src/interfaces/IEventManager.sol";
import {IEventPod} from "../../src/interfaces/IEventPod.sol";

contract upgradeEventPodScript is Script {
    address public ORACLE_POD = vm.envAddress("ORACLE_POD");

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("Deployer address:", deployerAddress);
        console.log("Event Pod Proxy:", ORACLE_POD);

        address proxyAdminAddress = getProxyAdminAddress(ORACLE_POD);
        console.log("Calculated Event Pod Proxy Admin:", proxyAdminAddress);

        ProxyAdmin messageManagerProxyAdmin = ProxyAdmin(proxyAdminAddress);

        vm.startBroadcast(deployerPrivateKey);

        EventPod newEventPodImplementation = new EventPod();

        console.log(
            "New EventPod implementation:",
            address(newEventPodImplementation)
        );

        messageManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(ORACLE_POD),
            address(newEventPodImplementation),
            ""
        );

        console.log("Upgrade completed successfully!");
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
