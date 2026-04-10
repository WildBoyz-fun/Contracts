// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC404} from "./libs/ERC404/interfaces/IERC404.sol";
import {ERC404Token} from "./ERC404Token.sol";
import {ITokenFactory} from "./TokenFactory.sol";
import "./libs/MaxGasPriceUpgradeable.sol";
import "./BondingCurve.sol";
import "./LiquidityProvider.sol";

import {IOwnerGroupContract} from "./libs/IOwnerGroupContract.sol";
import {IReferralTracker} from "./libs/IReferralTracker.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract LaunchPad is MaxGasPriceUpgradeable, UUPSUpgradeable {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _reentrancyStatus;

    modifier nonReentrant() {
        require(_reentrancyStatus != ENTERED, "ReentrancyGuard: reentrant call");
        _reentrancyStatus = ENTERED;
        _;
        _reentrancyStatus = NOT_ENTERED;
    }
    BondingCurve private _bondingCurveContract;
    IOwnerGroupContract private _ownerGroupContract;
    LiquidityProvider private _liquidityProviderContract;
    IReferralTracker private _referralTrackerContract;
    ITokenFactory private _tokenFactory;

    struct ContractInfo {
        address deployedBy;
        bool saleIsActive;
        bool isGraduated;
        uint256 maxSupply;
        uint256 totalSupply;
        uint256 ethDepositBalance;
        bool exists;
    }

    address private _treasuryAddress;
    uint256 public totalContractCount;
    address[] public launchedTokenContracts;
    mapping(address => address[]) public userDeployedContracts;

    uint256 public targetFundRasingAmount;
    uint8 public _feeRate;
    uint256 public totalAccumulatedFees;

    mapping(address => ContractInfo) public contractInfo;
    mapping(address => address) public graduatedPairs;

    event TokenPurchased(address indexed tokenAddress, address indexed buyer, uint256 amount, uint256 price);
    event TokenSold(address indexed tokenAddress, address indexed seller, uint256 amount, uint256 price);
    event ContractDeployed(address indexed contractAddress, address indexed deployedBy, string symbolName);
    event Received(address sender, uint amount);
    event SaleEnded(address contractAddress, uint256 contractTotalSupply, uint256 targetFundRasingAmount);
    event SuppliedLP(address indexed contractAddress, uint256 tokenAmount, uint256 ethAmount);
    event Graduated(address indexed tokenAddress, address indexed pairAddress, uint256 tokenAmount, uint256 ethAmount, uint256 lpTokensBurned);
    event EmergencyGraduated(address indexed tokenAddress, address indexed triggeredBy);

    modifier onlyDeployed(address ca) {
        require(contractInfo[ca].exists, "CND");
        _;
    }

    modifier onlyOwnerGroup() {
        require(_ownerGroupContract.isOwner(msg.sender), "Only Owner have a permission.");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address treasuryAddress,
        address bondingCurveContract,
        address ownerGroupContract
    ) external initializer {
        require(treasuryAddress != address(0), "Invalid treasury");
        require(bondingCurveContract != address(0), "Invalid bonding curve");
        require(ownerGroupContract != address(0), "Invalid owner group");

        __MaxGasPrice_init(msg.sender);

        _reentrancyStatus = NOT_ENTERED;

        _treasuryAddress = treasuryAddress;
        _bondingCurveContract = BondingCurve(bondingCurveContract);
        _ownerGroupContract = IOwnerGroupContract(ownerGroupContract);
        targetFundRasingAmount = 800_000_000 * 10 ** 18;
        _feeRate = 1;
    }

    function _authorizeUpgrade(address) internal override onlyOwnerGroup {}

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function getBalance() external view returns (uint) {
        return address(this).balance;
    }

    // --- Token Creation (via Factory) ---

    function createBioDiversityERC404Token(
        address tokenTreasuryAddress, uint256 maxSupply, string memory symbol, string memory name, uint256 taxPermil,
        string memory imageURI_, string memory trait_type_, string[5] memory trait_values_, string[5] memory images_,
        string memory description_
    ) public returns (address) {
        require(address(_tokenFactory) != address(0), "Factory not set");

        address contractAddress;
        {
            contractAddress = _tokenFactory.createToken(
                name, symbol, maxSupply, address(this), address(this),
                tokenTreasuryAddress, taxPermil, imageURI_, trait_type_, trait_values_, images_
            );
        }

        // Set description on-chain in the same tx
        if (bytes(description_).length > 0) {
            ERC404Token(contractAddress).setDescription(description_);
        }

        require(!contractInfo[contractAddress].exists, "AD");

        contractInfo[contractAddress] = ContractInfo({
            deployedBy: msg.sender,
            saleIsActive: true,
            isGraduated: false,
            maxSupply: maxSupply,
            totalSupply: 0,
            ethDepositBalance: 0,
            exists: true
        });

        totalContractCount++;
        launchedTokenContracts.push(contractAddress);
        userDeployedContracts[msg.sender].push(contractAddress);

        emit ContractDeployed(contractAddress, msg.sender, symbol);
        return contractAddress;
    }

    // --- View Functions ---

    function getContractEthBalance(address ca) external view returns (uint256) {
        return contractInfo[ca].ethDepositBalance;
    }

    function getContractTotalSupplyBalance(address ca) external view returns (uint256) {
        return contractInfo[ca].totalSupply;
    }

    function changeContractSaleStatus(address ca) public onlyOwnerGroup onlyDeployed(ca) returns (bool) {
        contractInfo[ca].saleIsActive = !contractInfo[ca].saleIsActive;
        return contractInfo[ca].saleIsActive;
    }

    function getContractSaleStatus(address ca) public view onlyDeployed(ca) returns (bool) {
        return contractInfo[ca].saleIsActive;
    }

    function getContractGraduationStatus(address ca) public view onlyDeployed(ca) returns (bool) {
        return contractInfo[ca].isGraduated;
    }

    function calculatePurchaseBalance(address ca, uint256 tokenAmount) external view onlyDeployed(ca) returns (uint256) {
        ContractInfo storage info = contractInfo[ca];
        return _bondingCurveContract.calculatePurchaseBalance(info.totalSupply, info.ethDepositBalance, tokenAmount);
    }

    function getLaunchedContractCount() external view returns (uint256) { return totalContractCount; }
    function getLaunchedTokenContracts() external view returns (address[] memory) { return launchedTokenContracts; }
    function getContractsDeployedBy(address deployer) external view returns (address[] memory) { return userDeployedContracts[deployer]; }
    function getGraduatedPair(address ca) external view returns (address) { return graduatedPairs[ca]; }

    // --- Buy / Sell ---

    function buyToken(address ca, uint256 minTokens) public payable validGasPrice nonReentrant returns (uint256) {
        ContractInfo storage info = contractInfo[ca];
        require(info.saleIsActive, "SNA");
        require(info.totalSupply < targetFundRasingAmount, "TFR");

        IERC404 token = IERC404(ca);
        uint256 deposit = (msg.value * 100) / (100 + _feeRate);
        uint256 fee = msg.value - deposit;
        require(deposit > 0, "Zero");

        uint256 amount = _bondingCurveContract.calculatePurchaseReturn(info.totalSupply, info.ethDepositBalance, deposit);
        require(amount >= minTokens, "Slippage exceeded");
        require(token.balanceOf(address(this)) >= amount, "Insufficient");

        totalAccumulatedFees += fee;
        info.totalSupply += amount;
        info.ethDepositBalance += deposit;

        require(token.transfer(msg.sender, amount), "Transfer failed");

        uint256 currentPrice = _bondingCurveContract.calculatePurchaseBalance(info.totalSupply, info.ethDepositBalance, 1e18);
        emit TokenPurchased(ca, msg.sender, amount, currentPrice);

        _recordReferral(IReferralTracker.ActivityType.TOKEN_BUY, msg.sender);

        if (info.totalSupply >= targetFundRasingAmount) {
            _graduateToken(ca, info);
        }

        return amount;
    }

    function sellToken(address ca, uint256 amount, uint256 minEth) validGasPrice nonReentrant public {
        ContractInfo storage info = contractInfo[ca];
        require(info.saleIsActive, "SNA");
        require(amount > 0, "Zero");

        IERC404 token = IERC404(ca);
        require(token.balanceOf(msg.sender) >= amount, "Insufficient balance");

        uint256 ethReturn = _bondingCurveContract.calculateSaleReturn(info.totalSupply, info.ethDepositBalance, amount);
        uint256 fee = (ethReturn * _feeRate) / 100;
        ethReturn -= fee;
        require(ethReturn >= minEth, "Slippage exceeded");

        require(token.transferFrom(msg.sender, address(this), amount), "TransferFrom failed");

        totalAccumulatedFees += fee;
        info.ethDepositBalance -= (ethReturn + fee);
        info.totalSupply -= amount;

        uint256 currentPrice = _bondingCurveContract.calculatePurchaseBalance(info.totalSupply, info.ethDepositBalance, 1e18);
        emit TokenSold(ca, msg.sender, amount, currentPrice);

        _recordReferral(IReferralTracker.ActivityType.TOKEN_SELL, msg.sender);

        (bool success, ) = payable(msg.sender).call{value: ethReturn}("");
        require(success, "ETH transfer failed");
    }

    // --- Graduation ---

    function _graduateToken(address ca, ContractInfo storage info) internal {
        info.saleIsActive = false;
        info.isGraduated = true;
        emit SaleEnded(ca, info.totalSupply, targetFundRasingAmount);

        if (address(_liquidityProviderContract) != address(0)) {
            IERC404 token = IERC404(ca);
            uint256 ethBal = info.ethDepositBalance;
            uint256 tokenBal = token.balanceOf(address(this));

            if (tokenBal > 0 && ethBal > 0) {
                info.ethDepositBalance = 0;

                ERC404Token(ca).setERC721TransferExempt(address(_liquidityProviderContract), true);
                token.transfer(address(_liquidityProviderContract), tokenBal);

                (address pair, uint256 lpBurned) = _liquidityProviderContract.addLiquidityETH{value: ethBal}(ca, tokenBal, ethBal);

                graduatedPairs[ca] = pair;
                ERC404Token(ca).setERC721TransferExempt(pair, true);

                emit SuppliedLP(ca, tokenBal, ethBal);
                emit Graduated(ca, pair, tokenBal, ethBal, lpBurned);
            }
        }
    }

    function emergencyGraduate(address ca) external onlyOwnerGroup onlyDeployed(ca) nonReentrant {
        ContractInfo storage info = contractInfo[ca];
        require(info.saleIsActive, "SNA");
        require(!info.isGraduated, "Already graduated");
        require(info.totalSupply > 0, "No tokens sold");

        emit EmergencyGraduated(ca, msg.sender);
        _graduateToken(ca, info);
    }

    // --- Admin ---

    function sendEthToTreasury(uint256 amount) external onlyOwnerGroup {
        require(amount <= totalAccumulatedFees, "IUF");
        require(address(this).balance >= amount, "NEE");
        totalAccumulatedFees -= amount;
        (bool success, ) = _treasuryAddress.call{value: amount}("");
        require(success, "ETF");
    }

    function setTokenFactory(address factoryAddress) external onlyOwnerGroup {
        require(factoryAddress != address(0), "Invalid");
        _tokenFactory = ITokenFactory(factoryAddress);
    }

    function setReferralTrackerContract(address addr) external onlyOwnerGroup {
        require(addr != address(0), "Invalid");
        _referralTrackerContract = IReferralTracker(addr);
    }

    function _recordReferral(IReferralTracker.ActivityType activityType, address user) internal {
        if (address(_referralTrackerContract) != address(0)) {
            try _referralTrackerContract.recordReferral(activityType, user) {} catch {}
        }
    }

    function setLiquidityProviderContract(address addr) external onlyOwnerGroup {
        require(addr != address(0), "Invalid");
        _liquidityProviderContract = LiquidityProvider(payable(addr));
    }

    function addLiquidityETH(address ca, uint256 tokenAmount, uint256 ethAmount) external onlyOwnerGroup nonReentrant {
        require(address(_liquidityProviderContract) != address(0), "LPCNA");
        require(contractInfo[ca].exists, "CND");
        IERC404(ca).transfer(address(_liquidityProviderContract), tokenAmount);
        _liquidityProviderContract.addLiquidityETH{value: ethAmount}(ca, tokenAmount, ethAmount);
        emit SuppliedLP(ca, tokenAmount, ethAmount);
    }

    // --- Configurable Parameters ---

    function setTargetFundRaisingAmount(uint256 amount) external onlyOwnerGroup {
        require(amount > 0, "Must be > 0");
        targetFundRasingAmount = amount;
    }

    function setFeeRate(uint8 rate) external onlyOwnerGroup {
        require(rate <= 10, "Max 10%");
        _feeRate = rate;
    }

    function setMaxGasPrice(uint256 newMax) public override onlyOwnerGroup returns (bool) {
        maxGasPrice = newMax;
        return true;
    }

    /// @notice Allow token deployer to set description on their token
    function setTokenDescription(address ca, string memory description_) external onlyDeployed(ca) {
        require(contractInfo[ca].deployedBy == msg.sender, "Only deployer");
        ERC404Token(ca).setDescription(description_);
    }

    // --- Admin View Helpers ---

    function getTokenFactory() external view returns (address) {
        return address(_tokenFactory);
    }

    function getLiquidityProvider() external view returns (address) {
        return address(_liquidityProviderContract);
    }

    function getReferralTracker() external view returns (address) {
        return address(_referralTrackerContract);
    }

    function getTreasuryAddress() external view returns (address) {
        return _treasuryAddress;
    }

    uint256[50] private __gap;
}
