// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC404Token} from "./ERC404Token.sol";
import {IOwnerGroupContract} from "./libs/IOwnerGroupContract.sol";

interface ITokenFactory {
    function createToken(
        string memory name, string memory symbol, uint256 maxSupply,
        address owner, address mintRecipient, address tokenTreasury, uint256 taxPermil,
        string memory imageURI, string memory traitType,
        string[5] memory traitValues, string[5] memory images
    ) external returns (address);
}

contract TokenFactory is ITokenFactory {
    IOwnerGroupContract private _ownerGroupContract;
    address public launchPad;

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

    constructor(address ownerGroupContract) {
        _ownerGroupContract = IOwnerGroupContract(ownerGroupContract);
    }

    function setLaunchPad(address _launchPad) external onlyOwnerGroup {
        require(_launchPad != address(0), "Invalid");
        launchPad = _launchPad;
    }

    function createToken(
        string memory name, string memory symbol, uint256 maxSupply,
        address owner, address mintRecipient, address tokenTreasury, uint256 taxPermil,
        string memory imageURI, string memory traitType,
        string[5] memory traitValues, string[5] memory images
    ) external onlyLaunchPadOrOwner returns (address) {
        ERC404Token newToken = new ERC404Token(
            name, symbol, maxSupply, owner, mintRecipient,
            tokenTreasury, taxPermil, imageURI, traitType, traitValues, images
        );
        return address(newToken);
    }
}
