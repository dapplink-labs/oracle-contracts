// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import {console, Script} from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {EmptyContract} from "../../src/utils/EmptyContract.sol";
import {EventPod} from "../../src/pod/EventPod.sol";
import {EventManager} from "../../src/core/EventManager.sol";

import {IEventManager} from "../../src/interfaces/IEventManager.sol";
import {IEventPod} from "../../src/interfaces/IEventPod.sol";

contract deployEventPodScript is Script {
    EmptyContract public emptyContract;

    ProxyAdmin public eventPodAdmin;
    EventPod public eventPod;
    EventPod public eventPodImplementation;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address eventManagerAddr = vm.envAddress("ORACLE_MANAGER");

        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        emptyContract = new EmptyContract();
        TransparentUpgradeableProxy proxyEventPod =
            new TransparentUpgradeableProxy(address(emptyContract), deployerAddress, "");
        eventPod = EventPod(address(proxyEventPod));
        eventPodImplementation = new EventPod();
        eventPodAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyEventPod)));

        console.log("eventPodImplementation===", address(eventPodImplementation));

        eventPodAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(eventPod)),
            address(eventPodImplementation),
            abi.encodeWithSelector(EventPod.initialize.selector, deployerAddress, eventManagerAddr)
        );

        //        EventManager(eventManagerAddr).addEventPodToFillWhitelist(proxyEventPod);

        console.log("deploy proxyEventPod:", address(proxyEventPod));
        string memory path = "deployed_addresses.json";
        string memory data = string(
            abi.encodePacked(
                '{"proxyEventPod": "',
                vm.toString(address(proxyEventPod)),
                '", ',
                '"eventPodImplementation": "',
                vm.toString(address(eventPodImplementation)),
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
