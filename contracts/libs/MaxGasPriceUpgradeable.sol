// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract MaxGasPriceUpgradeable is Initializable, OwnableUpgradeable {
    uint256 public maxGasPrice;

    function __MaxGasPrice_init(address owner_) internal onlyInitializing {
        __Ownable_init(owner_);
        maxGasPrice = 1 * 10 ** 18;
    }

    modifier validGasPrice() {
        require(tx.gasprice <= maxGasPrice, "Gas price too high");
        _;
    }

    function setMaxGasPrice(uint256 newMax) public onlyOwner returns (bool) {
        maxGasPrice = newMax;
        return true;
    }
}
