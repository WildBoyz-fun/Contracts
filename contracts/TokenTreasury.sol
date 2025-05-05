// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;


/// @title TokenTreasury - A simple treasury contract that can receive ETH
contract TokenTreasury {
    // Event to log received ETH
    event Received(address indexed sender, uint256 amount);

    address[] public owners;

    constructor(address[] memory owners_) {
        owners = owners_;
    }

    // Receive function to accept ETH transfers
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    // Fallback function in case ETH is sent with data
    fallback() external payable {
        emit Received(msg.sender, msg.value);
    }
}