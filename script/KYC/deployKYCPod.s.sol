// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import { console, Script } from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { EmptyContract } from "../../src/utils/EmptyContract.sol";
import { KYCPod } from "../../src/pod/KYCPod.sol";

contract deployKYCPodScript is Script {
    EmptyContract public emptyContract;

    ProxyAdmin public kycPodAdmin;
    KYCPod public kycPod;
    KYCPod public kycPodImplementation;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address kycManagerAddr = vm.envAddress("ORACLE_MANAGER");

        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        emptyContract = new EmptyContract();
        TransparentUpgradeableProxy proxyKYCPod = new TransparentUpgradeableProxy(address(emptyContract), deployerAddress, "");
        kycPod = KYCPod(address(proxyKYCPod));
        kycPodImplementation = new KYCPod();
        kycPodAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyKYCPod)));

        console.log("kycPodImplementation===", address(kycPodImplementation));

        // Owner must be KYCManager so verifyAndPodKYC can call recordVerification
        kycPodAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(kycPod)), address(kycPodImplementation), abi.encodeWithSelector(KYCPod.initialize.selector, deployerAddress, kycManagerAddr));

        // KYCManager(kycManagerAddr).addPodToFillWhitelist(proxyKYCPod);

        console.log("deploy proxyKYCPod:", address(proxyKYCPod));
        string memory path = "deployed_addresses.json";
        string memory data = string(abi.encodePacked('{"proxyKYCPod": "', vm.toString(address(proxyKYCPod)), '", ', '"kycPodImplementation": "', vm.toString(address(kycPodImplementation)), '"}'));
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
