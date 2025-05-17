// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ILaunchPadTokenTreasury} from "./libs/ILaunchPadTokenTreasury.sol";
import {IOwnerGroupContract} from "./libs/IOwnerGroupContract.sol";


contract LaunchPanTokenTreasury is ILaunchPadTokenTreasury {

    event WithdrawalEth(address indexed to, uint256 amount);
    
    IOwnerGroupContract private _ownerGroupContract;    

    modifier onlyOwner (){
        require(_ownerGroupContract.isOwner(msg.sender), "Only Owner have a permission.");
        _;
    }
    
    constructor(address ownerGroupContractAddress) {
        _ownerGroupContract = IOwnerGroupContract(ownerGroupContractAddress);
    }
    
    receive() external payable {}

    function sendEth(address payable to, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient ETH balance");
        require(to != address(0), "Invalid recipient");

        (bool success, ) = to.call{value: amount}("");
        require(success, "ETH transfer failed");

        emit WithdrawalEth(to, amount);
    }
}
