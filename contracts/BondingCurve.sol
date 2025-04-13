// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libs/BancorFormula.sol";

contract BondingCurve is BancorFormula {

    uint256 private _tokenSupplyOffset = 1197424701255807981000275879;
    uint256 private _depositBalanceOffset = 60310000000000000;
    uint32 private _reserveRatio = 100000; // 10%

    constructor() {
    }

    function calculatePurchaseReturn(
        uint256 tokenSupply,
        uint256 depositBalance,
        uint256 deposit
    ) public view returns (uint256) {
        return calculatePurchaseReturn(
            offsetTokenSupply(tokenSupply),
            offsetDepositBalance(depositBalance),
            _reserveRatio,
            deposit
        );
    }

    function calculatePurchaseBalance(
        uint256 tokenSupply,
        uint256 depositBalance,
        uint256 tokenAmountToPurchase
    ) public view returns (uint256) {
        return calculatePurchaseBalance(
            offsetTokenSupply(tokenSupply),
            offsetDepositBalance(depositBalance),
            _reserveRatio,
            tokenAmountToPurchase
        );
    }

    function calculateSaleReturn(
        uint256 tokenSupply,
        uint256 depositBalance,
        uint256 tokenAmount
    ) public view returns (uint256) {
        return calculateSaleReturn(
            offsetTokenSupply(tokenSupply),
            offsetDepositBalance(depositBalance),
            _reserveRatio,
            tokenAmount
        );
    }

    function offsetTokenSupply(uint256 tokenSupply) internal view returns (uint256) {
        return tokenSupply + _tokenSupplyOffset;
    }

    function offsetDepositBalance(uint256 depositBalance) internal view returns (uint256) {
        return depositBalance + _depositBalanceOffset;
    }
}