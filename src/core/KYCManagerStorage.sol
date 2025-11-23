// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IKYCManager.sol";

abstract contract KYCManagerStorage is Initializable, IKYCManager {
    uint256[50] private __gap;
}
