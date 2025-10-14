// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBancorFormula {
    function calculatePurchaseReturn(
        uint256 _supply,
        uint256 _connectorBalance,
        uint32 _connectorWeight,
        uint256 _depositAmount
    ) external view returns (uint256);

    function calculatePurchaseBalance(
        uint256 _supply,
        uint256 _connectorBalance,
        uint32 _connectorWeight,
        uint256 _tokenAmount
    ) external view returns (uint256);

    function calculateSaleReturn(
        uint256 _supply,
        uint256 _connectorBalance,
        uint32 _connectorWeight,
        uint256 _sellAmount
    ) external view returns (uint256);
}
