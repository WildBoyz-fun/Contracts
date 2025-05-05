// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import {ILaunchPadTokenTreasury} from "./libs/ILaunchPadTokenTreasury.sol";


contract LaunchPanTokenTreasury is Ownable, ILaunchPadTokenTreasury {

    event TreasuryWithdrawal(address indexed token, address indexed to, uint256 amount);
    
    constructor  (address owner) Ownable(owner) {}
    
    receive() external payable {}

    function sendETH(address payable to, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient ETH balance");
        require(to != address(0), "Invalid recipient");

        (bool success, ) = to.call{value: amount}("");
        require(success, "ETH transfer failed");
    }
}
