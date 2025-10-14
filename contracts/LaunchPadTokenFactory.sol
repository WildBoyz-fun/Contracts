// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./ERC404Token.sol";

error FactoryZeroAddress();
error FactoryNotAdmin();
error FactoryLaunchPadAlreadySet();
error FactoryLaunchPadNotSet();
error FactoryNotLaunchPad();

contract LaunchPadTokenFactory {
    address public admin;
    address public launchPad;

    uint256 private constant _DEFAULT_MAX_SUPPLY = 1_000_000_000 * 10 ** 18;

    constructor(address admin_) {
        if (admin_ == address(0)) {
            revert FactoryZeroAddress();
        }
        admin = admin_;
    }

    function setLaunchPad(address launchPad_) external {
        if (msg.sender != admin) {
            revert FactoryNotAdmin();
        }
        if (launchPad_ == address(0)) {
            revert FactoryZeroAddress();
        }
        if (launchPad != address(0)) {
            revert FactoryLaunchPadAlreadySet();
        }
        launchPad = launchPad_;
    }

    function deployToken(
        string memory symbol,
        string memory name,
        address tokenTreasuryAddress,
        uint256 taxPermil,
        string memory imageURI_,
        string memory trait_type_,
        string[5] memory trait_values_,
        string[5] memory images_
    ) external returns (address) {
        address launchPad_ = launchPad;
        if (launchPad_ == address(0)) {
            revert FactoryLaunchPadNotSet();
        }
        if (msg.sender != launchPad_) {
            revert FactoryNotLaunchPad();
        }

        ERC404Token newContract = new ERC404Token(
            name,
            symbol,
            _DEFAULT_MAX_SUPPLY,
            launchPad_,
            launchPad_,
            tokenTreasuryAddress,
            taxPermil,
            imageURI_,
            trait_type_,
            trait_values_,
            images_
        );

        return address(newContract);
    }
}
