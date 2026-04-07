// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ERC404Token} from "./ERC404Token.sol";
import {IOwnerGroupContract} from "./libs/IOwnerGroupContract.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface ITokenFactory {
    function createToken(
        string memory name, string memory symbol, uint256 maxSupply,
        address owner, address mintRecipient, address tokenTreasury, uint256 taxPermil,
        string memory imageURI, string memory traitType,
        string[5] memory traitValues, string[5] memory images
    ) external returns (address);
}

contract TokenFactory is Initializable, UUPSUpgradeable, ITokenFactory {
    using Clones for address;

    IOwnerGroupContract private _ownerGroupContract;
    address public launchPad;
    address public implementation;

    modifier onlyLaunchPadOrOwner() {
        require(
            msg.sender == launchPad || _ownerGroupContract.isOwner(msg.sender),
            "Not authorized"
        );
        _;
    }

    modifier onlyOwnerGroup() {
        require(_ownerGroupContract.isOwner(msg.sender), "Not owner");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address ownerGroupContract) external initializer {

        _ownerGroupContract = IOwnerGroupContract(ownerGroupContract);
    }

    function _authorizeUpgrade(address) internal override onlyOwnerGroup {}

    function setLaunchPad(address _launchPad) external onlyOwnerGroup {
        require(_launchPad != address(0), "Invalid");
        launchPad = _launchPad;
    }

    function setImplementation(address impl) external onlyOwnerGroup {
        require(impl != address(0), "Invalid");
        implementation = impl;
    }

    function createToken(
        string memory name, string memory symbol, uint256 maxSupply,
        address owner, address mintRecipient, address tokenTreasury, uint256 taxPermil,
        string memory imageURI, string memory traitType,
        string[5] memory traitValues, string[5] memory images
    ) external onlyLaunchPadOrOwner returns (address) {
        require(implementation != address(0), "Implementation not set");

        address clone = implementation.clone();
        ERC404Token(clone).initialize(
            name, symbol, maxSupply, owner, mintRecipient,
            tokenTreasury, taxPermil, imageURI, traitType, traitValues, images
        );
        return clone;
    }

    uint256[50] private __gap;
}
