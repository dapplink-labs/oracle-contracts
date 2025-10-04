// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { IVrfPod } from "../interfaces/IVrfPod.sol";


abstract contract VrfPodStorage is IVrfPod {
    struct RandomWordsInfo {
        bool fulfilled;
        uint256[] randomWords;
    }

    address public vrfManager;

    mapping(uint256 => RandomWordsInfo) public randomWordsMapping;

    uint256[100] private slot;
}
