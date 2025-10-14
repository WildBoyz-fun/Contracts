// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./libs/IBancorFormula.sol";

contract BondingCurve {

//    uint256 private _tokenSupplyOffset = 1197424701255807981000275879;  // Too large - causes overflow
//    uint256 private _depositBalanceOffset = 60310000000000000;
//    uint256 private _tokenSupplyOffset = 1762049353456217679748953228;  // Extremely large - causes issues
//    uint256 private _depositBalanceOffset = 970000000000000000;

    // Calibrated offsets (24 decimals) to raise ~40 ETH when selling 800M tokens
    uint256 private _tokenSupplyOffset = 1762049368563532800000000000;
    uint256 private _depositBalanceOffset = 970000004909802666;
    uint32 private _reserveRatio = 100000; // 10%
    IBancorFormula public immutable bancorFormula;

    constructor(address formulaAddress) {
        require(formulaAddress != address(0), "Invalid formula address");
        bancorFormula = IBancorFormula(formulaAddress);
    }

    function calculatePurchaseReturn(
        uint256 tokenSupply,
        uint256 depositBalance,
        uint256 deposit
    ) public view returns (uint256) {
        return bancorFormula.calculatePurchaseReturn(
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
        return bancorFormula.calculatePurchaseBalance(
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
        return bancorFormula.calculateSaleReturn(
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
