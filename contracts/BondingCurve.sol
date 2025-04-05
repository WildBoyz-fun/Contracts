// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libs/BancorFormula.sol";

contract BondingCurve is BancorFormula {

    uint256 private _tokenSupplyOffset = 3_690_287_251_496_824_536_722_139_764;
    uint256 private _depositBalanceOffset = 1**18;
    uint32 private _reserveRatio = 100000; // 10%

    constructor() {
    }

    function calculatePurchaseReturn(uint256 tokenSupply, uint256 depositBalance, uint256 deposit) public view returns (uint256) {
        return calculatePurchaseReturn(
            offsetTokenSupply(tokenSupply),
            offsetDepositBalance(depositBalance),
            _reserveRatio,
            deposit
        );
    }

    function calculateSaleReturn(uint256 tokenSupply, uint256 depositBalance, uint256 tokenAmount) public view returns (uint256) {
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