// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IEventPod} from "../interfaces/IEventPod.sol";

abstract contract EventPodStorage is IEventPod {
    struct PredictEventInfo {
        uint256 requestId;
        string eventDescribe;
        string predictPosSide;
        string predictNegSide;
        string winner;
    }

    address public eventManager;

    mapping(uint256 => PredictEventInfo) public predictEventMapping;

    uint256[100] private slot;
}
