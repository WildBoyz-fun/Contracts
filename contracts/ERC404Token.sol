//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC404U16} from "./libs/ERC404/ERC404U16.sol";

contract ERC404Token is Ownable, ERC404U16 {
  error InsufficientFee();
  error AlreadyInitialized();

  address private _tokenTreasury;
  uint256 private _taxPermil;
  bool private _initialized;

  string public dataURI;
  string public baseTokenURI;
  string[5] private images;
  string[6] private trait_values;
  string public description;

  constructor() ERC404U16("", "", 24) Ownable(msg.sender) {
    _initialized = true;
  }

  function initialize(
    string memory name_,
    string memory symbol_,
    uint256 initialSupply_,
    address initialOwner_,
    address initialMintRecipient_,
    address tokenTreasury_,
    uint256 taxPermil_,
    string memory imageURI_,
    string memory trait_type_,
    string[5] memory trait_values_,
    string[5] memory images_
  ) external {
    if (_initialized) revert AlreadyInitialized();
    _initialized = true;

    name = name_;
    symbol = symbol_;
    _transferOwnership(initialOwner_);
    _setERC721TransferExempt(initialMintRecipient_, true);
    _mintERC20(initialMintRecipient_, initialSupply_);
    _tokenTreasury = tokenTreasury_;
    _taxPermil = taxPermil_;

    dataURI = imageURI_;
    trait_values = [
      trait_values_[0],
      trait_values_[1],
      trait_values_[2],
      trait_values_[3],
      trait_values_[4],
      trait_type_];
    images = [
      images_[0],
      images_[1],
      images_[2],
      images_[3],
      images_[4]];
  }

  /// @notice Set token description (callable by owner, e.g. LaunchPad)
  function setDescription(string memory description_) external onlyOwner {
    description = description_;
  }

  function setERC721TransferExempt(address account_, bool value_) external onlyOwner {
    _setERC721TransferExempt(account_, value_);
  }

  function setTokenURI(string memory tokenURI_) public onlyOwner {
    baseTokenURI = tokenURI_;
  }

  function setDataURI(string memory dataURI_) public onlyOwner {
    dataURI = dataURI_;
  }

  function setTraitTypeValues(
    string memory trait_type_,
    string memory trait_value1_, string memory trait_value2_,
    string memory trait_value3_, string memory trait_value4_,
    string memory trait_value5_
  ) public onlyOwner {
    trait_values[5] = trait_type_;
    trait_values[0] = trait_value1_;
    trait_values[1] = trait_value2_;
    trait_values[2] = trait_value3_;
    trait_values[3] = trait_value4_;
    trait_values[4] = trait_value5_;
  }

  function setRarityImages(
    string memory img1_, string memory img2_,
    string memory img3_, string memory img4_,
    string memory img5_
  ) public onlyOwner {
    images[0] = img1_;
    images[1] = img2_;
    images[2] = img3_;
    images[3] = img4_;
    images[4] = img5_;
  }

  function DOMAIN_SEPARATOR() public view override returns (bytes32) {
    return _computeDomainSeparator();
  }

  function tokenURI(uint256 id_) public view override returns (string memory) {
    uint256 id16_;
    if (id_ > ID_ENCODING_PREFIX) {
        id16_ = id_ - ID_ENCODING_PREFIX;
    } else {
        id16_ = id_;
    }

    if (bytes(baseTokenURI).length > 0) {
      return string.concat(baseTokenURI, Strings.toString(id16_));
    } else {
      uint8 seed = uint8(bytes1(keccak256(abi.encodePacked(id16_))));
      string memory image;
      string memory color;

      if (seed <= 100) {
        image = images[0];
        color = trait_values[0];
      } else if (seed <= 160) {
        image = images[1];
        color = trait_values[1];
      } else if (seed <= 210) {
        image = images[2];
        color = trait_values[2];
      } else if (seed <= 240) {
        image = images[3];
        color = trait_values[3];
      } else if (seed <= 255) {
        image = images[4];
        color = trait_values[4];
      }

      // Use on-chain description if set, otherwise default
      string memory desc = bytes(description).length > 0
        ? description
        : "An ERC-404 token on WildBoyz.fun with 5 rarity tiers.";

      string memory jsonPreImage = string.concat(
        string.concat(
          string.concat(
            string.concat(
              '{"name": "',
              name),
            string.concat(
              '#',
              Strings.toString(id16_)
            )
          ),
          string.concat(
            '","description":"',
            string.concat(desc, '","external_url":"https://wildboyz.fun/","image":"'))
        ),
        string.concat(dataURI, image)
      );
      string memory jsonPostImage = string.concat(
        string.concat(
            '","attributes":[{"trait_type":"',
            trait_values[5]
        ),
        string.concat(
            '","value":"',
            color
        )
      );
      string memory jsonPostTraits = '"}]}';

      return
        string.concat(
          "data:application/json;utf8,",
          string.concat(
            string.concat(jsonPreImage, jsonPostImage),
            jsonPostTraits
          )
        );
    }
  }

  function ercTransferFromWithFee(
      address from_,
      uint256 value_
  ) internal returns (uint256) {
    uint256 fee = value_ * _taxPermil / 1000;
    _transferERC20WithERC721(from_, _tokenTreasury, fee);
    return value_ - fee;
  }

  function erc20TransferFrom(
    address from_,
    address to_,
    uint256 value_
  ) public virtual override returns (bool) {
    if (from_ == address(0)) { revert InvalidSender(); }
    if (to_ == address(0)) { revert InvalidRecipient(); }

    uint256 allowed = allowance[from_][msg.sender];
    if (allowed != type(uint256).max) {
      allowance[from_][msg.sender] = allowed - value_;
    }

    value_ = ercTransferFromWithFee(from_, value_);
    return _transferERC20WithERC721(from_, to_, value_);
  }

  function transfer(address to_, uint256 value_) public virtual override returns (bool) {
    if (to_ == address(0)) { revert InvalidRecipient(); }
    value_ = ercTransferFromWithFee(msg.sender, value_);
    return _transferERC20WithERC721(msg.sender, to_, value_);
  }
}
