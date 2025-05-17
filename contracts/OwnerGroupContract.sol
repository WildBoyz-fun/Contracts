// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IOwnerGroupContract} from "./libs/IOwnerGroupContract.sol";

contract OwnerGroupContract is IOwnerGroupContract{

    uint private ownerCount=0;
    mapping(address => bool) private owners;

    event RegisterOwner(
        address indexed owner
    );
    event UnRegisterOwner(
        address indexed owner
    );    

    constructor(address[] memory initialOwners) {

        for (uint256 i = 0; i < initialOwners.length; i++) {
            require(initialOwners[i] != address(0), "Invalid owner");
            owners[initialOwners[i]] = true;
            ownerCount++;
        }
    }

    modifier onlyOwner() {
        require(owners[msg.sender], "not owner");
        _;
    }

    function getOwnerCount() external view returns (uint)
    {
        return ownerCount;
    }

    function isOwner(address ownerAddress) external view returns (bool)
    {
        return owners[ownerAddress];
    }

    function registerOwner(address newOwner) public onlyOwner {
        require(!owners[newOwner] , "already registered.");
        require(newOwner != msg.sender , "can't process");
        
        owners[newOwner] = true;
        
        emit RegisterOwner(newOwner);
    }

    function unRegisterOwner(address targetOwner) public onlyOwner {
        require(owners[targetOwner] , "unknown address");
        require(targetOwner != msg.sender , "can't process");
        
        owners[targetOwner] = false;
        
        emit UnRegisterOwner(targetOwner);
    }

}