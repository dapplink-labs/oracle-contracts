// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";

import {VrfPodStorage} from "./VrfPodStorage.sol";

contract VrfPod is Initializable, OwnableUpgradeable, VrfPodStorage {
    modifier onlyVrfManager() {
        require(msg.sender == vrfManager, "DappLinkVRF.onlyVrfManager can call this function");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, address _vrfManager) public initializer {
        __Ownable_init(initialOwner);
        vrfManager = _vrfManager;
    }

    function requestRandomWords(uint256 _requestId, uint256 _numWords) external {
        randomWordsMapping[_requestId] = RandomWordsInfo({randomWords: new uint256[](0), fulfilled: false});
        emit RequestSent(_requestId, _numWords, address(this));
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) external onlyVrfManager {
        randomWordsMapping[_requestId] = RandomWordsInfo({fulfilled: true, randomWords: _randomWords});
        emit FillRandomWords(_requestId, _randomWords);
    }

    function getRandomWordsWithStatus(uint256 _requestId)
        external
        view
        returns (bool fulfilled, uint256[] memory randomWords)
    {
        return (randomWordsMapping[_requestId].fulfilled, randomWordsMapping[_requestId].randomWords);
    }

    function setVrfManager(address _vrfManager) external onlyOwner {
        vrfManager = _vrfManager;
    }
}
