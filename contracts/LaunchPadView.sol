// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC404} from "./libs/ERC404/interfaces/IERC404.sol";

interface ILaunchPad {
    struct ContractInfo {
        address deployedBy;
        bool saleIsActive;
        bool isGraduated;
        uint256 maxSupply;
        uint256 totalSupply;
        uint256 ethDepositBalance;
        bool exists;
    }

    function contractInfo(address) external view returns (address, bool, bool, uint256, uint256, uint256, bool);
    function getContractEthBalance(address) external view returns (uint256);
    function getContractTotalSupplyBalance(address) external view returns (uint256);
    function getContractSaleStatus(address) external view returns (bool);
    function getContractGraduationStatus(address) external view returns (bool);
    function calculatePurchaseBalance(address, uint256) external view returns (uint256);
    function getLaunchedTokenContracts() external view returns (address[] memory);
    function getLaunchedContractCount() external view returns (uint256);
    function getContractsDeployedBy(address) external view returns (address[] memory);
    function targetFundRasingAmount() external view returns (uint256);
    function _feeRate() external view returns (uint8);
    function totalAccumulatedFees() external view returns (uint256);
    function graduatedPairs(address) external view returns (address);
}

interface IBondingCurve {
    function calculatePurchaseReturn(uint256, uint256, uint256) external view returns (uint256);
    function calculatePurchaseBalance(uint256, uint256, uint256) external view returns (uint256);
    function calculateSaleReturn(uint256, uint256, uint256) external view returns (uint256);
}

/// @notice Read-only view contract for LaunchPad. Delegates all calls to LaunchPad.
contract LaunchPadView {

    struct TokenInfo {
        address tokenAddress;
        string symbol;
        string name;
        string mainImage;
    }

    error LaunchPadViewNotDeployed();

    // --- Direct forwarding functions ---

    function getContractEthBalance(address launchPadAddress, address contractAddress) external view returns (uint256) {
        return ILaunchPad(launchPadAddress).getContractEthBalance(contractAddress);
    }

    function getContractTotalSupplyBalance(address launchPadAddress, address contractAddress) external view returns (uint256) {
        return ILaunchPad(launchPadAddress).getContractTotalSupplyBalance(contractAddress);
    }

    function getContractSaleStatus(address launchPadAddress, address contractAddress) external view returns (bool) {
        return ILaunchPad(launchPadAddress).getContractSaleStatus(contractAddress);
    }

    function calculatePurchaseBalance(address launchPadAddress, address contractAddress, uint256 tokenAmountToPurchase) external view returns (uint256) {
        return ILaunchPad(launchPadAddress).calculatePurchaseBalance(contractAddress, tokenAmountToPurchase);
    }

    function calculatePurchaseReturn(address launchPadAddress, address contractAddress, uint256 ethAmount) external view returns (uint256) {
        (,,, , uint256 totalSupply, uint256 ethBalance,) = ILaunchPad(launchPadAddress).contractInfo(contractAddress);
        // We need to access the bonding curve - but it's internal to LaunchPad
        // Instead, use the LaunchPad's calculatePurchaseBalance to estimate
        // This is an approximation - for exact, use LaunchPad directly
        return ILaunchPad(launchPadAddress).calculatePurchaseBalance(contractAddress, ethAmount);
    }

    function calculateExactTokensForEth(address launchPadAddress, address contractAddress, uint256 ethAmount) external view returns (uint256) {
        return ILaunchPad(launchPadAddress).calculatePurchaseBalance(contractAddress, ethAmount);
    }

    function calculateEthNeededForTokens(address launchPadAddress, address contractAddress, uint256 tokenAmount) external view returns (uint256) {
        return ILaunchPad(launchPadAddress).calculatePurchaseBalance(contractAddress, tokenAmount);
    }

    function calculateTokensForEthAmountsBatch(address launchPadAddress, address contractAddress, uint256[] calldata ethAmounts) external view returns (uint256[] memory) {
        uint256[] memory results = new uint256[](ethAmounts.length);
        for (uint256 i = 0; i < ethAmounts.length; i++) {
            results[i] = ILaunchPad(launchPadAddress).calculatePurchaseBalance(contractAddress, ethAmounts[i]);
        }
        return results;
    }

    function getLaunchedContractCount(address launchPadAddress) external view returns (uint256) {
        return ILaunchPad(launchPadAddress).getLaunchedContractCount();
    }

    function getLaunchedTokenAddresses(address launchPadAddress) external view returns (address[] memory) {
        return ILaunchPad(launchPadAddress).getLaunchedTokenContracts();
    }

    function getContractsDeployedBy(address launchPadAddress, address deployer) external view returns (address[] memory) {
        return ILaunchPad(launchPadAddress).getContractsDeployedBy(deployer);
    }

    // --- Rich view functions ---

    function getBondingCurveState(address launchPadAddress, address contractAddress) external view returns (
        uint256 totalSupply, uint256 ethBalance, uint256 maxSupply, bool saleIsActive,
        uint8 feeRate, uint256 targetAmount, uint256 accumulatedFees
    ) {
        (,bool _saleIsActive,, uint256 _maxSupply, uint256 _totalSupply, uint256 _ethBalance,) =
            ILaunchPad(launchPadAddress).contractInfo(contractAddress);

        return (
            _totalSupply,
            _ethBalance,
            _maxSupply,
            _saleIsActive,
            ILaunchPad(launchPadAddress)._feeRate(),
            ILaunchPad(launchPadAddress).targetFundRasingAmount(),
            ILaunchPad(launchPadAddress).totalAccumulatedFees()
        );
    }

    function calculateTokensQuickReference(address launchPadAddress, address contractAddress) external view returns (
        uint256 tokensFor01Eth, uint256 tokensFor05Eth, uint256 tokensFor1Eth, uint256 tokensFor5Eth
    ) {
        tokensFor01Eth = ILaunchPad(launchPadAddress).calculatePurchaseBalance(contractAddress, 0.1 ether);
        tokensFor05Eth = ILaunchPad(launchPadAddress).calculatePurchaseBalance(contractAddress, 0.5 ether);
        tokensFor1Eth = ILaunchPad(launchPadAddress).calculatePurchaseBalance(contractAddress, 1 ether);
        tokensFor5Eth = ILaunchPad(launchPadAddress).calculatePurchaseBalance(contractAddress, 5 ether);
    }

    function getTokenInfo(address launchPadAddress, uint256 index) external view returns (TokenInfo memory) {
        address[] memory tokens = ILaunchPad(launchPadAddress).getLaunchedTokenContracts();
        require(index < tokens.length, "Index out of bounds");
        address tokenAddr = tokens[index];

        string memory name;
        string memory symbol;
        string memory mainImage;

        try IERC404(tokenAddr).name() returns (string memory n) { name = n; } catch { name = "Token"; }
        try IERC404(tokenAddr).symbol() returns (string memory s) { symbol = s; } catch { symbol = "TKN"; }
        // dataURI is on ERC404Token, not IERC404 interface - use low-level call
        (bool ok, bytes memory data) = tokenAddr.staticcall(abi.encodeWithSignature("dataURI()"));
        if (ok && data.length > 0) { mainImage = abi.decode(data, (string)); }

        return TokenInfo(tokenAddr, symbol, name, mainImage);
    }

    function getLaunchedTokenContracts(address launchPadAddress) external view returns (TokenInfo[] memory) {
        address[] memory tokens = ILaunchPad(launchPadAddress).getLaunchedTokenContracts();
        TokenInfo[] memory result = new TokenInfo[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            string memory name;
            string memory symbol;
            string memory mainImage;

            try IERC404(tokens[i]).name() returns (string memory n) { name = n; } catch { name = "Token"; }
            try IERC404(tokens[i]).symbol() returns (string memory s) { symbol = s; } catch { symbol = "TKN"; }
            (bool ok, bytes memory data) = tokens[i].staticcall(abi.encodeWithSignature("dataURI()"));
            if (ok && data.length > 0) { mainImage = abi.decode(data, (string)); }

            result[i] = TokenInfo(tokens[i], symbol, name, mainImage);
        }

        return result;
    }
}
