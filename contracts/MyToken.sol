// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {
    bool isMinted = false;

    constructor(address initialOwner)
    ERC20("MyToken", "MTK")
    Ownable(initialOwner)
    {}

    function initialMint(address toAddress, uint256 amount) public onlyOwner() {
        require(isMinted == false, "Already Minted");
        _mint(toAddress, amount);
        isMinted = true;
    }
}
