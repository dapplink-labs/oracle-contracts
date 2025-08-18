// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Vm.sol";
import { console, Script } from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { EmptyContract } from "../src/utils/EmptyContract.sol";
import { OraclePod } from "../src/base/OraclePod.sol";
import { IOracleManager } from "../src/interfaces/IOracleManager.sol";
import { IOraclePod } from "../src/interfaces/IOraclePod.sol";


contract deployOraclePodScript is Script {
    EmptyContract public emptyContract;

    ProxyAdmin public oraclePodAdmin;
    OraclePod public oraclePod;
    OraclePod public oraclePodImplementation;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oracleManagerAddr = vm.envAddress("ORACLE_MANAGER");

        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        emptyContract = new EmptyContract();
        TransparentUpgradeableProxy proxyOraclePod = new TransparentUpgradeableProxy(address(emptyContract), deployerAddress, "");
        oraclePod = OraclePod(address(proxyOraclePod));
        oraclePodImplementation = new OraclePod();
        oraclePodAdmin = ProxyAdmin(getProxyAdminAddress(address(proxyOraclePod)));

        console.log("oraclePodImplementation===", address(oraclePodImplementation));

        oraclePodAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(oraclePod)),
            address(oraclePodImplementation),
            abi.encodeWithSelector(
                OraclePod.initialize.selector,
                deployerAddress,
                oracleManagerAddr
            )
        );

        IOracleManager(oracleManagerAddr).addOraclePodToFillWhitelist(IOraclePod(address(proxyOraclePod)));


        console.log("deploy proxyOraclePod:", address(proxyOraclePod));
        string memory path = "deployed_addresses.json";
        string memory data = string(abi.encodePacked(
            '{"proxyOraclePod": "', vm.toString(address(proxyOraclePod)), '", ',
            '"oraclePodImplementation": "', vm.toString(address(oraclePodImplementation)), '"}'
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
