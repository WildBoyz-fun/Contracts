// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./BondingCurve.sol";

interface ILaunchPad {
    function contractInfo(address)
        external
        view
        returns (address deployedBy, bool saleIsActive, uint256 maxSupply, uint256 totalSupply, uint256 ethDepositBalance, bool exists);

    function FEE_RATE() external view returns (uint8);

    function TARGET_FUNDRAISING_AMOUNT() external view returns (uint256);

    function bondingCurveAddress() external view returns (address);

    function totalContractCount() external view returns (uint256);

    function launchedTokenContracts(uint256) external view returns (address tokenAddress);

}

interface IERC404Metadata {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function dataURI() external view returns (string memory);
}

error LaunchPadViewNotDeployed();

contract LaunchPadView {
    function calculateTokensForEthAmountsBatch(
        address launchPadAddress,
        address contractAddress,
        uint256[] calldata ethAmounts
    ) external view returns (uint256[] memory) {
        ILaunchPad launchPad = ILaunchPad(launchPadAddress);
        (, , , uint256 totalSupply, uint256 ethDepositBalance, bool exists) =
            launchPad.contractInfo(contractAddress);
        if (!exists) revert LaunchPadViewNotDeployed();

        uint8 feeRate = launchPad.FEE_RATE();
        BondingCurve bondingCurve = BondingCurve(launchPad.bondingCurveAddress());

        uint256[] memory results = new uint256[](ethAmounts.length);
        for (uint256 i = 0; i < ethAmounts.length; i++) {
            uint256 deposit = ethAmounts[i] / (100 + feeRate) * 100;
            results[i] = bondingCurve.calculatePurchaseReturn(
                totalSupply,
                ethDepositBalance,
                deposit
            );
        }

        return results;
    }

    function calculateTokensQuickReference(
        address launchPadAddress,
        address contractAddress
    )
        external
        view
        returns (
            uint256 tokens_for_001_eth,
            uint256 tokens_for_01_eth,
            uint256 tokens_for_1_eth,
            uint256 tokens_for_10_eth
        )
    {
        ILaunchPad launchPad = ILaunchPad(launchPadAddress);
        (, , , uint256 totalSupply, uint256 ethDepositBalance, bool exists) =
            launchPad.contractInfo(contractAddress);
        if (!exists) revert LaunchPadViewNotDeployed();

        uint8 feeRate = launchPad.FEE_RATE();
        BondingCurve bondingCurve = BondingCurve(launchPad.bondingCurveAddress());

        uint256 deposit001 = 1000000000000000 / (100 + feeRate) * 100;
        uint256 deposit01 = 10000000000000000 / (100 + feeRate) * 100;
        uint256 deposit1 = 100000000000000000 / (100 + feeRate) * 100;
        uint256 deposit10 = 1000000000000000000 / (100 + feeRate) * 100;

        tokens_for_001_eth = bondingCurve.calculatePurchaseReturn(totalSupply, ethDepositBalance, deposit001);
        tokens_for_01_eth = bondingCurve.calculatePurchaseReturn(totalSupply, ethDepositBalance, deposit01);
        tokens_for_1_eth = bondingCurve.calculatePurchaseReturn(totalSupply, ethDepositBalance, deposit1);
        tokens_for_10_eth = bondingCurve.calculatePurchaseReturn(totalSupply, ethDepositBalance, deposit10);
    }

    function calculateExactTokensForEth(
        address launchPadAddress,
        address contractAddress,
        uint256 ethAmount
    ) external view returns (uint256) {
        ILaunchPad launchPad = ILaunchPad(launchPadAddress);
        (, , , uint256 totalSupply, uint256 ethDepositBalance, bool exists) =
            launchPad.contractInfo(contractAddress);
        if (!exists) revert LaunchPadViewNotDeployed();

        uint8 feeRate = launchPad.FEE_RATE();
        uint256 deposit = ethAmount / (100 + feeRate) * 100;

        BondingCurve bondingCurve = BondingCurve(launchPad.bondingCurveAddress());

        return bondingCurve.calculatePurchaseReturn(
            totalSupply,
            ethDepositBalance,
            deposit
        );
    }

    function calculateEthNeededForTokens(
        address launchPadAddress,
        address contractAddress,
        uint256 tokenAmount
    ) external view returns (uint256) {
        ILaunchPad launchPad = ILaunchPad(launchPadAddress);
        (, , , uint256 totalSupply, uint256 ethDepositBalance, bool exists) =
            launchPad.contractInfo(contractAddress);
        if (!exists) revert LaunchPadViewNotDeployed();

        uint8 feeRate = launchPad.FEE_RATE();
        BondingCurve bondingCurve = BondingCurve(launchPad.bondingCurveAddress());

        uint256 ethNeeded = bondingCurve.calculatePurchaseBalance(
            totalSupply,
            ethDepositBalance,
            tokenAmount
        );

        return ethNeeded * (100 + feeRate) / 100;
    }

    function getBondingCurveState(
        address launchPadAddress,
        address contractAddress
    )
        external
        view
        returns (
            uint256 currentTotalSupply,
            uint256 currentEthBalance,
            uint256 maxSupply,
            bool saleActive,
            uint8 feeRate,
            uint256 targetFunding,
            uint256 remainingToTarget
        )
    {
        ILaunchPad launchPad = ILaunchPad(launchPadAddress);
        ( , bool saleIsActive, uint256 maxSupplyLocal, uint256 totalSupply, uint256 ethDepositBalance, bool exists) =
            launchPad.contractInfo(contractAddress);
        if (!exists) revert LaunchPadViewNotDeployed();

        currentTotalSupply = totalSupply;
        currentEthBalance = ethDepositBalance;
        maxSupply = maxSupplyLocal;
        saleActive = saleIsActive;
        feeRate = launchPad.FEE_RATE();
        targetFunding = launchPad.TARGET_FUNDRAISING_AMOUNT();
        remainingToTarget = totalSupply >= targetFunding ? 0 : targetFunding - totalSupply;
    }

    function getContractEthBalance(address launchPadAddress, address contractAddress) external view returns (uint256) {
        ILaunchPad launchPad = ILaunchPad(launchPadAddress);
        (, , , , uint256 ethDepositBalance, bool exists) = launchPad.contractInfo(contractAddress);
        if (!exists) revert LaunchPadViewNotDeployed();
        return ethDepositBalance;
    }

    function getContractTotalSupplyBalance(address launchPadAddress, address contractAddress) external view returns (uint256) {
        ILaunchPad launchPad = ILaunchPad(launchPadAddress);
        (, , , uint256 totalSupply, , bool exists) = launchPad.contractInfo(contractAddress);
        if (!exists) revert LaunchPadViewNotDeployed();
        return totalSupply;
    }

    function getContractSaleStatus(address launchPadAddress, address contractAddress) external view returns (bool) {
        ILaunchPad launchPad = ILaunchPad(launchPadAddress);
        (, bool saleIsActive, , , , bool exists) = launchPad.contractInfo(contractAddress);
        if (!exists) revert LaunchPadViewNotDeployed();
        return saleIsActive;
    }

    function calculatePurchaseBalance(
        address launchPadAddress,
        address contractAddress,
        uint256 tokenAmountToPurchase
    ) external view returns (uint256) {
        ILaunchPad launchPad = ILaunchPad(launchPadAddress);
        (, , , uint256 totalSupply, uint256 ethDepositBalance, bool exists) =
            launchPad.contractInfo(contractAddress);
        if (!exists) revert LaunchPadViewNotDeployed();

        BondingCurve bondingCurve = BondingCurve(launchPad.bondingCurveAddress());

        return bondingCurve.calculatePurchaseBalance(totalSupply, ethDepositBalance, tokenAmountToPurchase);
    }

    function calculatePurchaseReturn(
        address launchPadAddress,
        address contractAddress,
        uint256 ethAmount
    ) external view returns (uint256) {
        ILaunchPad launchPad = ILaunchPad(launchPadAddress);
        (, , , uint256 totalSupply, uint256 ethDepositBalance, bool exists) =
            launchPad.contractInfo(contractAddress);
        if (!exists) revert LaunchPadViewNotDeployed();

        uint8 feeRate = launchPad.FEE_RATE();
        uint256 adjustedEthAmount = ethAmount / (100 + feeRate) * 100;
        BondingCurve bondingCurve = BondingCurve(launchPad.bondingCurveAddress());

        return bondingCurve.calculatePurchaseReturn(totalSupply, ethDepositBalance, adjustedEthAmount);
    }

    function getLaunchedContractCount(address launchPadAddress) external view returns (uint256) {
        return ILaunchPad(launchPadAddress).totalContractCount();
    }

    struct TokenInfoView {
        address tokenAddress;
        string symbol;
        string name;
        string mainImage;
    }

    function getLaunchedTokenContracts(address launchPadAddress) external view returns (TokenInfoView[] memory) {
        ILaunchPad launchPad = ILaunchPad(launchPadAddress);
        uint256 count = launchPad.totalContractCount();
        TokenInfoView[] memory result = new TokenInfoView[](count);

        for (uint256 i = 0; i < count; i++) {
            address tokenAddress = launchPad.launchedTokenContracts(i);
            result[i] = _buildTokenInfo(tokenAddress);
        }

        return result;
    }

    function getLaunchedTokenAddresses(address launchPadAddress) external view returns (address[] memory) {
        ILaunchPad launchPad = ILaunchPad(launchPadAddress);
        uint256 count = launchPad.totalContractCount();
        address[] memory addresses = new address[](count);

        for (uint256 i = 0; i < count; i++) {
            addresses[i] = launchPad.launchedTokenContracts(i);
        }

        return addresses;
    }

    function getTokenInfo(address launchPadAddress, uint256 index) external view returns (TokenInfoView memory) {
        ILaunchPad launchPad = ILaunchPad(launchPadAddress);
        address tokenAddress = launchPad.launchedTokenContracts(index);
        return _buildTokenInfo(tokenAddress);
    }

    function getContractsDeployedBy(address launchPadAddress, address deployer) external view returns (address[] memory) {
        ILaunchPad launchPad = ILaunchPad(launchPadAddress);
        uint256 count = launchPad.totalContractCount();
        address[] memory temp = new address[](count);
        uint256 found;

        for (uint256 i = 0; i < count; i++) {
            address tokenAddress = launchPad.launchedTokenContracts(i);
            (address deployedBy, , , , , bool exists) = launchPad.contractInfo(tokenAddress);
            if (exists && deployedBy == deployer) {
                temp[found] = tokenAddress;
                found++;
            }
        }

        address[] memory result = new address[](found);
        for (uint256 i = 0; i < found; i++) {
            result[i] = temp[i];
        }

        return result;
    }

    function _buildTokenInfo(address tokenAddress) private view returns (TokenInfoView memory info) {
        string memory symbol;
        string memory name;
        string memory mainImage;

        try IERC404Metadata(tokenAddress).symbol() returns (string memory s) {
            symbol = s;
        } catch {
            symbol = "";
        }

        try IERC404Metadata(tokenAddress).name() returns (string memory n) {
            name = n;
        } catch {
            name = symbol;
        }

        try IERC404Metadata(tokenAddress).dataURI() returns (string memory uri) {
            mainImage = uri;
        } catch {
            mainImage = "";
        }

        info = TokenInfoView(tokenAddress, symbol, name, mainImage);
    }
}
