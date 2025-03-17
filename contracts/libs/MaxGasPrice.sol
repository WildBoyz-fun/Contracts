// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MaxGasPrice is Ownable {
    uint256 public maxGasPrice = 1 * 10**18;

    constructor() Ownable(msg.sender) {

    }

    modifier validGasPrice() {
        require(
            tx.gasprice <= maxGasPrice,
            "Must send equal to or lower than maximum gas price to mitigate front running attacks."
        );
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