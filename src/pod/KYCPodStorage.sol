// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IKYCPod.sol";

abstract contract KYCPodStorage is IKYCPod {
    mapping(address => Record) public kycRecords; // user => Record

    uint256[100] private __gap;
}
