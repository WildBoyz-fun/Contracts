// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IOwnerGroupContract} from "./libs/IOwnerGroupContract.sol";

contract OwnerGroupContract is IOwnerGroupContract {

    uint private ownerCount = 0;
    mapping(address => bool) private owners;
    address[] private ownerList;
    mapping(address => uint256) private ownerIndex; // for efficient removal

    event RegisterOwner(address indexed owner, address indexed addedBy);
    event UnRegisterOwner(address indexed owner, address indexed removedBy);

    constructor(address[] memory initialOwners) {
        for (uint256 i = 0; i < initialOwners.length; i++) {
            require(initialOwners[i] != address(0), "Invalid owner");
            require(!owners[initialOwners[i]], "Duplicate owner");
            owners[initialOwners[i]] = true;
            ownerIndex[initialOwners[i]] = ownerList.length;
            ownerList.push(initialOwners[i]);
            ownerCount++;
        }
    }

    modifier onlyOwner() {
        require(owners[msg.sender], "Not owner");
        _;
    }

    function getOwnerCount() external view returns (uint) {
        return ownerCount;
    }

    function isOwner(address ownerAddress) external view returns (bool) {
        return owners[ownerAddress];
    }

    /// @notice Get all owner addresses
    function getOwners() external view returns (address[] memory) {
        return ownerList;
    }

    function registerOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid address");
        require(!owners[newOwner], "Already registered");

        owners[newOwner] = true;
        ownerIndex[newOwner] = ownerList.length;
        ownerList.push(newOwner);
        ownerCount++;

        emit RegisterOwner(newOwner, msg.sender);
    }

    function unRegisterOwner(address targetOwner) public onlyOwner {
        require(owners[targetOwner], "Not an owner");
        require(targetOwner != msg.sender, "Cannot remove self");
        require(ownerCount > 1, "Cannot remove last owner");

        owners[targetOwner] = false;
        ownerCount--;

        // Swap-and-pop to keep ownerList clean
        uint256 idx = ownerIndex[targetOwner];
        uint256 lastIdx = ownerList.length - 1;
        if (idx != lastIdx) {
            address lastOwner = ownerList[lastIdx];
            ownerList[idx] = lastOwner;
            ownerIndex[lastOwner] = idx;
        }
        ownerList.pop();
        delete ownerIndex[targetOwner];

        emit UnRegisterOwner(targetOwner, msg.sender);
    }
}
