// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply
    ) ERC20(name_, symbol_) {
        // initialSupply는 18 decimals 기준으로 입력 (예: 100 * 10 ** 18)
        _mint(msg.sender, initialSupply);
    }
}