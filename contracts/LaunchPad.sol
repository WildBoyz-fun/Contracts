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
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

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

    uint256 public targetFundRasingAmount; // legacy (token-based, kept for storage layout)
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
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event ReferralFailed(address indexed user, bytes reason);
    event RefundPending(address indexed user, uint256 amount);
    event RefundClaimed(address indexed user, uint256 amount);

    modifier onlyDeployed(address ca) {
        require(contractInfo[ca].exists, "CND");
        _;
    }

    modifier onlyOwnerGroup() {
        require(_ownerGroupContract.isOwner(msg.sender), "Only Owner have a permission.");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
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
        targetFundRasingAmount = 800_000_000 * 10 ** 18; // legacy
        targetEthAmount = 10 ether; // default: 10 ETH to graduate
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
    ) public whenNotPaused returns (address) {
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

    function buyToken(address ca, uint256 minTokens) public payable validGasPrice nonReentrant whenNotPaused returns (uint256) {
        ContractInfo storage info = contractInfo[ca];
        require(info.saleIsActive, "SNA");
        require(info.ethDepositBalance < targetEthAmount, "Target reached");

        IERC404 token = IERC404(ca);
        require(msg.value >= 1000, "Deposit too small"); // minimum 1000 wei to prevent precision loss
        uint256 totalDeposit = (msg.value * 100) / (100 + _feeRate);
        require(totalDeposit > 0, "Zero");

        // Cap deposit so it doesn't exceed graduation target
        uint256 remaining = targetEthAmount - info.ethDepositBalance;
        uint256 deposit = totalDeposit > remaining ? remaining : totalDeposit;
        uint256 fee = (deposit * _feeRate) / 100;
        uint256 actualCost = deposit + fee;

        uint256 amount = _bondingCurveContract.calculatePurchaseReturn(info.totalSupply, info.ethDepositBalance, deposit);
        require(amount >= minTokens, "Slippage exceeded");
        require(token.balanceOf(address(this)) >= amount, "Insufficient");

        // Effects
        totalAccumulatedFees += fee;
        info.totalSupply += amount;
        info.ethDepositBalance += deposit;

        // Transfer tokens
        require(token.transfer(msg.sender, amount), "Transfer failed");

        // Refund excess ETH if deposit was capped (pull pattern to prevent DOS)
        if (msg.value > actualCost) {
            uint256 refundAmount = msg.value - actualCost;
            (bool refundSuccess, ) = payable(msg.sender).call{value: refundAmount}("");
            if (!refundSuccess) {
                pendingRefunds[msg.sender] += refundAmount;
                emit RefundPending(msg.sender, refundAmount);
            }
        }

        uint256 currentPrice = _bondingCurveContract.calculatePurchaseBalance(info.totalSupply, info.ethDepositBalance, 1e18);
        emit TokenPurchased(ca, msg.sender, amount, currentPrice);

        _recordReferral(IReferralTracker.ActivityType.TOKEN_BUY, msg.sender);

        // Graduate when ETH target reached
        if (info.ethDepositBalance >= targetEthAmount) {
            _graduateToken(ca, info);
        }

        return amount;
    }

    function sellToken(address ca, uint256 amount, uint256 minEth) validGasPrice nonReentrant whenNotPaused public {
        ContractInfo storage info = contractInfo[ca];
        require(info.saleIsActive, "SNA");
        require(amount > 0, "Zero");

        IERC404 token = IERC404(ca);
        require(token.balanceOf(msg.sender) >= amount, "Insufficient balance");

        uint256 ethReturn = _bondingCurveContract.calculateSaleReturn(info.totalSupply, info.ethDepositBalance, amount);
        uint256 fee = (ethReturn * _feeRate) / 100;
        ethReturn -= fee;
        require(ethReturn >= minEth, "Slippage exceeded");

        // Effects FIRST (CEI pattern)
        totalAccumulatedFees += fee;
        info.ethDepositBalance -= (ethReturn + fee);
        info.totalSupply -= amount;

        // Interactions AFTER
        require(token.transferFrom(msg.sender, address(this), amount), "TransferFrom failed");

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
        emit SaleEnded(ca, info.ethDepositBalance, targetEthAmount);

        if (address(_liquidityProviderContract) != address(0)) {
            IERC404 token = IERC404(ca);
            uint256 ethBal = info.ethDepositBalance;
            uint256 tokenBal = token.balanceOf(address(this));

            if (tokenBal > 0 && ethBal > 0) {
                ERC404Token erc404 = ERC404Token(ca);

                // Set ERC721 transfer exempt for all addresses in the LP creation flow
                erc404.setERC721TransferExempt(address(_liquidityProviderContract), true);
                address routerAddr = address(_liquidityProviderContract.router());
                erc404.setERC721TransferExempt(routerAddr, true);

                // Get or create pair so we can set it exempt before token transfers
                address wethAddr = _liquidityProviderContract.WETH();
                address factoryAddr = _liquidityProviderContract.factory();
                address pair = IUniswapV2Factory(factoryAddr).getPair(ca, wethAddr);
                if (pair == address(0)) {
                    pair = IUniswapV2Factory(factoryAddr).createPair(ca, wethAddr);
                }
                erc404.setERC721TransferExempt(pair, true);

                // Measure actual received amount (token tax may reduce transfer)
                uint256 lpBalBefore = token.balanceOf(address(_liquidityProviderContract));
                token.transfer(address(_liquidityProviderContract), tokenBal);
                uint256 actualReceived = token.balanceOf(address(_liquidityProviderContract)) - lpBalBefore;

                (address returnedPair, uint256 lpBurned) = _liquidityProviderContract.addLiquidityETH{value: ethBal}(ca, actualReceived, ethBal);
                require(returnedPair != address(0), "LP pair creation failed");
                require(returnedPair == pair, "Pair address mismatch");

                // Zero balance AFTER successful LP creation (atomicity)
                info.ethDepositBalance = 0;
                graduatedPairs[ca] = returnedPair;

                emit SuppliedLP(ca, actualReceived, ethBal);
                emit Graduated(ca, returnedPair, actualReceived, ethBal, lpBurned);
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

    /// @notice Recover stuck ETH from graduated tokens where LP creation failed
    function recoverStuckGraduation(address ca) external onlyOwnerGroup onlyDeployed(ca) nonReentrant {
        ContractInfo storage info = contractInfo[ca];
        require(info.isGraduated, "Not graduated");
        require(info.ethDepositBalance > 0, "No ETH to recover");
        require(address(_liquidityProviderContract) != address(0), "Set LP first");

        IERC404 token = IERC404(ca);
        uint256 ethBal = info.ethDepositBalance;
        uint256 tokenBal = token.balanceOf(address(this));

        if (tokenBal > 0) {
            ERC404Token erc404 = ERC404Token(ca);
            erc404.setERC721TransferExempt(address(_liquidityProviderContract), true);
            erc404.setERC721TransferExempt(address(_liquidityProviderContract.router()), true);
            address wethAddr = _liquidityProviderContract.WETH();
            address factoryAddr = _liquidityProviderContract.factory();
            address pair = IUniswapV2Factory(factoryAddr).getPair(ca, wethAddr);
            if (pair == address(0)) {
                pair = IUniswapV2Factory(factoryAddr).createPair(ca, wethAddr);
            }
            erc404.setERC721TransferExempt(pair, true);

            uint256 lpBalBefore = token.balanceOf(address(_liquidityProviderContract));
            token.transfer(address(_liquidityProviderContract), tokenBal);
            uint256 actualReceived = token.balanceOf(address(_liquidityProviderContract)) - lpBalBefore;

            (address returnedPair, uint256 lpBurned) = _liquidityProviderContract.addLiquidityETH{value: ethBal}(ca, actualReceived, ethBal);
            require(returnedPair != address(0), "LP pair creation failed");
            require(returnedPair == pair, "Pair address mismatch");
            info.ethDepositBalance = 0;
            graduatedPairs[ca] = returnedPair;
            emit Graduated(ca, returnedPair, actualReceived, ethBal, lpBurned);
        } else {
            info.ethDepositBalance = 0;
            // No tokens left — refund ETH to treasury
            (bool success, ) = _treasuryAddress.call{value: ethBal}("");
            require(success, "ETH transfer failed");
        }
    }

    // --- Admin ---

    function pause() external onlyOwnerGroup {
        require(!paused, "Already paused");
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwnerGroup {
        require(paused, "Not paused");
        paused = false;
        emit Unpaused(msg.sender);
    }

    function sendEthToTreasury(uint256 amount) external onlyOwnerGroup {
        require(amount <= totalAccumulatedFees, "IUF");
        require(address(this).balance >= amount, "NEE");
        totalAccumulatedFees -= amount;
        (bool success, ) = _treasuryAddress.call{value: amount}("");
        require(success, "ETF");
    }

    /// @notice Emergency withdraw ETH to treasury (bypasses fee accounting)
    function emergencyWithdrawETH(uint256 amount) external onlyOwnerGroup {
        require(address(this).balance >= amount, "Insufficient balance");
        (bool success, ) = _treasuryAddress.call{value: amount}("");
        require(success, "Transfer failed");
    }

    /// @notice Emergency withdraw ERC20 tokens to treasury
    function emergencyWithdrawToken(address token, uint256 amount) external onlyOwnerGroup {
        require(token != address(0), "Invalid token");
        uint256 bal = IERC404(token).balanceOf(address(this));
        require(bal >= amount, "Insufficient balance");
        IERC404(token).transfer(_treasuryAddress, amount);
    }

    /// @notice Update owner group contract (for multisig migration)
    function setOwnerGroup(address newOwnerGroup) external onlyOwnerGroup {
        require(newOwnerGroup != address(0), "Invalid");
        _ownerGroupContract = IOwnerGroupContract(newOwnerGroup);
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
            try _referralTrackerContract.recordReferral(activityType, user) {} catch (bytes memory reason) {
                emit ReferralFailed(user, reason);
            }
        }
    }

    function setLiquidityProviderContract(address addr) external onlyOwnerGroup {
        require(addr != address(0), "Invalid");
        _liquidityProviderContract = LiquidityProvider(payable(addr));
    }

    function addLiquidityETH(address ca, uint256 tokenAmount, uint256 ethAmount) external onlyOwnerGroup nonReentrant {
        require(address(_liquidityProviderContract) != address(0), "LPCNA");
        require(contractInfo[ca].exists, "CND");
        require(ethAmount <= totalAccumulatedFees, "Cannot use deposited ETH");
        totalAccumulatedFees -= ethAmount;

        ERC404Token erc404 = ERC404Token(ca);
        erc404.setERC721TransferExempt(address(_liquidityProviderContract), true);
        erc404.setERC721TransferExempt(address(_liquidityProviderContract.router()), true);
        address wethAddr = _liquidityProviderContract.WETH();
        address factoryAddr = _liquidityProviderContract.factory();
        address pair = IUniswapV2Factory(factoryAddr).createPair(ca, wethAddr);
        erc404.setERC721TransferExempt(pair, true);

        IERC404(ca).transfer(address(_liquidityProviderContract), tokenAmount);
        _liquidityProviderContract.addLiquidityETH{value: ethAmount}(ca, tokenAmount, ethAmount);
        emit SuppliedLP(ca, tokenAmount, ethAmount);
    }

    // --- Configurable Parameters ---

    function setTargetFundRaisingAmount(uint256 amount) external onlyOwnerGroup {
        require(amount > 0, "Must be > 0");
        targetFundRasingAmount = amount;
    }

    function setTargetEthAmount(uint256 amount) external onlyOwnerGroup {
        require(amount > 0, "Must be > 0");
        targetEthAmount = amount;
    }

    function setFeeRate(uint8 rate) external onlyOwnerGroup {
        require(rate <= 10, "Max 10%");
        _feeRate = rate;
    }

    /// @notice Sweep rounding dust ETH that's not accounted for (paginated to avoid gas DoS)
    /// @param startIndex Start index in launchedTokenContracts array
    /// @param batchSize Number of contracts to check (0 = all remaining)
    function sweepDust(uint256 startIndex, uint256 batchSize) external onlyOwnerGroup {
        uint256 len = launchedTokenContracts.length;
        require(startIndex <= len, "Start out of bounds");

        uint256 end = batchSize == 0 ? len : startIndex + batchSize;
        if (end > len) end = len;

        // Calculate total accounted ETH (fees + token deposits in this batch)
        uint256 accounted = totalAccumulatedFees;
        for (uint256 i = startIndex; i < end; i++) {
            accounted += contractInfo[launchedTokenContracts[i]].ethDepositBalance;
        }

        // Only sweep if we scanned all contracts (full sweep) to avoid partial accounting
        require(startIndex == 0 && end == len, "Must sweep all for accuracy");

        uint256 dust = address(this).balance > accounted ? address(this).balance - accounted : 0;
        if (dust > 0) {
            (bool success, ) = _treasuryAddress.call{value: dust}("");
            require(success, "Transfer failed");
        }
    }

    /// @notice Get total accounted ETH across a range of tokens (for off-chain pre-calculation)
    function getAccountedEth(uint256 startIndex, uint256 batchSize) external view returns (uint256 accounted) {
        uint256 len = launchedTokenContracts.length;
        if (startIndex >= len) return 0;
        uint256 end = batchSize == 0 ? len : startIndex + batchSize;
        if (end > len) end = len;
        for (uint256 i = startIndex; i < end; i++) {
            accounted += contractInfo[launchedTokenContracts[i]].ethDepositBalance;
        }
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

    uint256 public targetEthAmount; // ETH-based graduation target
    bool public paused;
    mapping(address => uint256) public pendingRefunds;

    /// @notice Claim pending refund that failed during buyToken
    function claimRefund() external nonReentrant {
        uint256 amount = pendingRefunds[msg.sender];
        require(amount > 0, "No pending refund");
        pendingRefunds[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Refund transfer failed");
        emit RefundClaimed(msg.sender, amount);
    }

    uint256[47] private __gap;
}
