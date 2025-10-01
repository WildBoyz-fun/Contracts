// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libs/BancorFormula.sol";

contract BondingCurve is BancorFormula {

//    uint256 private _tokenSupplyOffset = 1197424701255807981000275879;  // Too large - causes overflow
//    uint256 private _depositBalanceOffset = 60310000000000000;
//    uint256 private _tokenSupplyOffset = 1762049353456217679748953228;  // Extremely large - causes issues
//    uint256 private _depositBalanceOffset = 970000000000000000;

    // Calibrated offsets (24 decimals) to raise ~40 ETH when selling 800M tokens
    uint256 private _tokenSupplyOffset = 1762049368563532800000000000;
    uint256 private _depositBalanceOffset = 970000004909802666;
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

    // Batch calculation for multiple ETH amounts - for real-time UI updates
    function calculatePurchaseReturnBatch(
        uint256 tokenSupply,
        uint256 depositBalance,
        uint256[] memory deposits
    ) public view returns (uint256[] memory) {
        uint256[] memory results = new uint256[](deposits.length);
        
        for (uint256 i = 0; i < deposits.length; i++) {
            results[i] = calculatePurchaseReturn(tokenSupply, depositBalance, deposits[i]);
        }
        
        return results;
    }

    // Quick reference calculation for common ETH amounts
    function calculatePurchaseReturnQuick(
        uint256 tokenSupply,
        uint256 depositBalance
    ) public view returns (
        uint256 tokens_001_eth,  // 0.001 ETH
        uint256 tokens_01_eth,   // 0.01 ETH  
        uint256 tokens_1_eth,    // 0.1 ETH
        uint256 tokens_10_eth    // 1 ETH
    ) {
        tokens_001_eth = calculatePurchaseReturn(tokenSupply, depositBalance, 1000000000000000);      // 0.001 ETH
        tokens_01_eth = calculatePurchaseReturn(tokenSupply, depositBalance, 10000000000000000);     // 0.01 ETH
        tokens_1_eth = calculatePurchaseReturn(tokenSupply, depositBalance, 100000000000000000);     // 0.1 ETH
        tokens_10_eth = calculatePurchaseReturn(tokenSupply, depositBalance, 1000000000000000000);   // 1 ETH
    }

    // Real-time calculation for any ETH amount with fee consideration
    function calculatePurchaseReturnWithFee(
        uint256 tokenSupply,
        uint256 depositBalance,
        uint256 msgValue,
        uint8 feeRate
    ) public view returns (uint256) {
        // Apply the same fee calculation as LaunchPad contract
        uint256 deposit = msgValue / (100 + feeRate) * 100;
        return calculatePurchaseReturn(tokenSupply, depositBalance, deposit);
    }

    // Batch calculation with fee consideration
    function calculatePurchaseReturnBatchWithFee(
        uint256 tokenSupply,
        uint256 depositBalance,
        uint256[] memory msgValues,
        uint8 feeRate
    ) public view returns (uint256[] memory) {
        uint256[] memory results = new uint256[](msgValues.length);
        
        for (uint256 i = 0; i < msgValues.length; i++) {
            uint256 deposit = msgValues[i] / (100 + feeRate) * 100;
            results[i] = calculatePurchaseReturn(tokenSupply, depositBalance, deposit);
        }
        
        return results;
    }
}
