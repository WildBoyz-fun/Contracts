// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IOwnerGroupContract {
    function isOwner(address owenerAddress) external view returns (bool);
    function getOwnerCount() external view returns (uint);
}