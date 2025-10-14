// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";

error GasPriceTooHigh();

contract MaxGasPrice is Ownable {
    uint256 public maxGasPrice = 1 * 10**18;

    constructor(address owner) Ownable(owner) {

    }

    modifier validGasPrice() {
        if (tx.gasprice > maxGasPrice) {
            revert GasPriceTooHigh();
        }
        _;
    }

    function setMaxGasPrice(uint256 newMax)
    public
    onlyOwner
    returns (bool)
    {
        maxGasPrice = newMax;
        return true;
    }
}
