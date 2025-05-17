//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


interface ILaunchPadTokenTreasury {
    function sendEth(address payable to, uint256 amount) external;
}