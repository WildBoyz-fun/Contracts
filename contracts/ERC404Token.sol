//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC404U16} from "./libs/ERC404/ERC404U16.sol";

contract ERC404Token is Ownable, ERC404U16 {
  error InsufficientFee();
//  event TransferFeePaid(bytes data);
  address private _tokenTreasury;
  uint256 private _taxPermil;

  string[5] private metadataURIs;
  string[6] private trait_values;

  constructor(
    string memory name_,
    string memory symbol_,
    uint256 initialSupply_,
    address initialOwner_,
    address initialMintRecipient_,
    address tokenTreasury_,
    uint256 taxPermil_,
    string memory trait_type_,
    string[5] memory trait_values_,
    string[5] memory metadataURIs_
  ) ERC404U16(name_, symbol_, 18) Ownable(initialOwner_) {
    // Do not mint the ERC721s to the initial owner, as it's a waste of gas.
    _setERC721TransferExempt(initialMintRecipient_, true);
    _mintERC20(initialMintRecipient_, initialSupply_);
    _tokenTreasury = tokenTreasury_;
    _taxPermil = taxPermil_;
    // set default trait and image values
    trait_values = [
      trait_values_[0],
      trait_values_[1],
      trait_values_[2],
      trait_values_[3],
      trait_values_[4],
      trait_type_];
    // ["Green","Blue","Purple","Orange","Red","Color"]
    _setMetadataURIsInternal(metadataURIs_);
  }

  function setERC721TransferExempt(
    address account_,
    bool value_
  ) external onlyOwner {
    _setERC721TransferExempt(account_, value_);
  }

  function setTraitTypeValues(
    string memory trait_type_,
    string memory trait_value1_, string memory trait_value2_,
    string memory trait_value3_, string memory trait_value4_,
    string memory trait_value5_
  ) public onlyOwner {
    // Color : Green Blue Purple Orange Red
    trait_values[5] = trait_type_;
    trait_values[0] = trait_value1_;
    trait_values[1] = trait_value2_;
    trait_values[2] = trait_value3_;
    trait_values[3] = trait_value4_;
    trait_values[4] = trait_value5_;
  }

  function setMetadataURIs(
    string memory uri1_,
    string memory uri2_,
    string memory uri3_,
    string memory uri4_,
    string memory uri5_
  ) public onlyOwner {
    string[5] memory uris = [uri1_, uri2_, uri3_, uri4_, uri5_];
    _setMetadataURIsInternal(uris);
  }

  function _setMetadataURIsInternal(string[5] memory metadataURIs_) internal {
    metadataURIs = [
      metadataURIs_[0],
      metadataURIs_[1],
      metadataURIs_[2],
      metadataURIs_[3],
      metadataURIs_[4]
    ];

    for (uint256 i = 0; i < metadataURIs.length; i++) {
      require(bytes(metadataURIs[i]).length > 0, "Metadata URI missing");
    }
  }

  function tokenURI(uint256 id_) public view override returns (string memory) {
    uint256 id16_;
    if (id_ > ID_ENCODING_PREFIX) {
        id16_ = id_ - ID_ENCODING_PREFIX;
    } else {
        id16_ = id_;
    }

    uint8 seed = uint8(bytes1(keccak256(abi.encodePacked(id16_))));
    uint8 rarityIndex;

    if (seed <= 100) {
      rarityIndex = 0;
    } else if (seed <= 160) {
      rarityIndex = 1;
    } else if (seed <= 210) {
      rarityIndex = 2;
    } else if (seed <= 240) {
      rarityIndex = 3;
    } else {
      rarityIndex = 4;
    }

    string memory metadataURI = metadataURIs[rarityIndex];
    require(bytes(metadataURI).length > 0, "Metadata URI missing");
    return metadataURI;
  }

  function ercTransferFromWithFee(
      address from_,
      uint256 value_
  ) public returns (uint256) {
    uint256 fee = value_ * _taxPermil / 1000;

    _transferERC20WithERC721(from_, _tokenTreasury, fee);

    return value_ - fee;
  }

  function erc20TransferFrom(
    address from_,
    address to_,
    uint256 value_
  ) public virtual override returns (bool) {
    // Prevent transferring tokens from 0x0.
    if (from_ == address(0)) {
      revert InvalidSender();
    }

    // Prevent burning tokens to 0x0.
    if (to_ == address(0)) {
      revert InvalidRecipient();
    }

    // Intention is to transfer as ERC-20 token (value).
    uint256 allowed = allowance[from_][msg.sender];

    // Check that the operator has sufficient allowance.
    if (allowed != type(uint256).max) {
      allowance[from_][msg.sender] = allowed - value_;
    }

    value_ = ercTransferFromWithFee(from_, value_);

    // Transferring ERC-20s directly requires the _transfer function.
    // Handles ERC-721 exemptions internally.
    return _transferERC20WithERC721(from_, to_, value_);
  }

  function transfer(address to_, uint256 value_) public virtual override returns (bool) {
    // Prevent burning tokens to 0x0.
    if (to_ == address(0)) {
      revert InvalidRecipient();
    }

    value_ = ercTransferFromWithFee(msg.sender, value_);

    // Transferring ERC-20s directly requires the _transfer function.
    // Handles ERC-721 exemptions internally.
    return _transferERC20WithERC721(msg.sender, to_, value_);
  }

}
