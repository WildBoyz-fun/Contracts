// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC404} from "./libs/ERC404/interfaces/IERC404.sol";
import {ERC404Token} from "./ERC404Token.sol";
import "./libs/MaxGasPrice.sol";
import "./BondingCurve.sol";
import "./TokenTreasury.sol";
import "./LiquidityProvider.sol";

import {IOwnerGroupContract} from "./libs/IOwnerGroupContract.sol";


contract LaunchPad is MaxGasPrice {
    IERC404 private _tokenContract;
    BondingCurve private _bondingCurveContract;
    IOwnerGroupContract private _ownerGroupContract;    
    LiquidityProvider private _liquidityProviderContract;

    struct ContractInfo {
        address deployedBy;
        bool saleIsActive;     // sale or not sale
        uint256 maxSupply;   // Max supply token amount
        uint256 totalSupply;   // bonding curve parameters: Total supply(sold) token amount
        uint256 ethDepositBalance; // bonding curve parameters: Total ETH amount from token supply(Sold)
        bool exists;
    }

    struct TokenInfo {
        address tokenAddress;
        string symbol;
        string name;
        string mainImage;
    }

    // Transaction history structure for bonding curve calculations
    struct TransactionRecord {
        uint256 timestamp;
        address user;
        address tokenAddress;
        string transactionType; // "BUY" or "SELL"
        uint256 ethAmount;      // ETH amount (before fee for buy, after fee for sell)
        uint256 tokenAmount;    // Token amount
        uint256 pricePerToken;  // Price per token in wei (ethAmount / tokenAmount)
        uint256 totalSupplyAfter; // Total supply after this transaction
        uint256 ethBalanceAfter;  // ETH balance after this transaction
        bytes32 txHash;         // Transaction hash
        uint256 blockNumber;    // Block number
    }

    address private _treasuryAddress;
    uint256 public totalContractCount;
    TokenInfo[] public launchedTokenContracts;
    mapping(address => address[]) public userDeployedContracts;

    uint256 targetFundRasingAmount = 800_000_000 * 10 ** 18;
    // buy / sell eth fee %
    uint8 public _feeRate = 1;

    mapping(address => ContractInfo) public contractInfo;
    
    // Transaction history storage
    mapping(address => TransactionRecord[]) public tokenTransactionHistory;
    mapping(address => TransactionRecord[]) public userTransactionHistory;
    TransactionRecord[] public allTransactions;
    uint256 public totalTransactionCount;

    // events
    event TokensPurchased(address indexed buyer, uint256 amount);
    event TokenSold(address indexed buyer, uint256 amount);
    event ContractDeployed(
        address indexed contractAddress,
        address indexed deployedBy,
        string symbolName
    );
    // Event to log ETH received
    event Received(address sender, uint amount);
    event SaleEnded(address contractAddress, uint256 contractTotalSupply, uint256 targetFundRasingAmount);
    event SuppliedLP(
        address indexed contractAddress,
        uint256 tokenAmount,
        uint256 ethAmount
    );
    
    // Transaction history events
    event TransactionRecorded(
        address indexed user,
        address indexed tokenAddress,
        string transactionType,
        uint256 ethAmount,
        uint256 tokenAmount,
        uint256 pricePerToken
    );

    modifier onlyDeployed(address contractAddress) {
        require(contractInfo[contractAddress].exists, "CND"); // Contract Not Deployed
        _;
    }

    modifier onlyOwnerGroup () {
        require(_ownerGroupContract.isOwner(msg.sender), "Only Owner have a permission.");
        _;
    }

    // This function is called when ETH is sent to the contract without data
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    // Get the current balance of the contract
    function getBalance() external view returns (uint) {
        return address(this).balance;
    }

    constructor (address treasuryAddress, address bondingCurveContract, address ownerGroupContract) MaxGasPrice(msg.sender) {
        _treasuryAddress = treasuryAddress;
        _bondingCurveContract = BondingCurve(bondingCurveContract);
        _ownerGroupContract = IOwnerGroupContract(ownerGroupContract);
    }

    uint256 private constant _TOKEN_CREATION_FEE = 0.001 ether;

    uint256 private constant _DEFAULT_MAX_SUPPLY = 1_000_000_000 * 10 ** 18;

    function createBioDiversityERC404Token(
        address tokenTreasuryAddress,
        uint256 /*maxSupply*/,
        string memory symbol,
        string memory name,
        uint256 taxPermil,
        string memory imageURI_,
        string memory trait_type_,
        string[5] memory trait_values_,
        string[5] memory images_
    ) public payable returns (address) {
        require(msg.value == _TOKEN_CREATION_FEE, "Creation fee is 0.001 ETH");

        (bool feeTransferred, ) = _treasuryAddress.call{value: msg.value}("");
        require(feeTransferred, "Fee transfer failed");

        // 토큰 생성
        ERC404Token newContract = new ERC404Token(name, symbol, _DEFAULT_MAX_SUPPLY, address(this), address(this), tokenTreasuryAddress, taxPermil, imageURI_, trait_type_, trait_values_, images_);
    
        address contractAddress = address(newContract); 
        
        // Already Deployed (AD)
        require(!contractInfo[contractAddress].exists, "AD");

        contractInfo[contractAddress] = ContractInfo({
            deployedBy: msg.sender,
            saleIsActive: true,
            maxSupply: _DEFAULT_MAX_SUPPLY,
            totalSupply: 0,
            ethDepositBalance: 0,
            exists: true
        });

        totalContractCount++;
        launchedTokenContracts.push(TokenInfo({
            tokenAddress: contractAddress,
            symbol: symbol,
            name: name,
            mainImage: imageURI_
        }));
        userDeployedContracts[msg.sender].push(contractAddress);
        
        // Emit event for tracking
        emit ContractDeployed(contractAddress, msg.sender, symbol);
    
        return (contractAddress);
    }

    function getContractEthBalance(address contractAddress) external view returns (uint256) {
        return contractInfo[contractAddress].ethDepositBalance;
    }

    function getContractTotalSupplyBalance(address contractAddress) external view returns (uint256) {
        return contractInfo[contractAddress].totalSupply;
    }

    function changeContractSaleStatus(address contractAddress) public onlyOwnerGroup onlyDeployed(contractAddress) returns (bool) {
        contractInfo[contractAddress].saleIsActive = !contractInfo[contractAddress].saleIsActive;
        return contractInfo[contractAddress].saleIsActive;
    }

    function getContractSaleStatus(address contractAddress) public view onlyDeployed(contractAddress) returns (bool) {
        return contractInfo[contractAddress].saleIsActive;
    }

    // 사고싶은 토큰 수량에 맞는 이더 수량 Return
    function calculatePurchaseBalance(address contractAddress, uint256 tokenAmountToPurchase) external view onlyDeployed(contractAddress) returns (uint256) {
        ContractInfo storage info = contractInfo[contractAddress];
        return _bondingCurveContract.calculatePurchaseBalance(info.totalSupply, info.ethDepositBalance, tokenAmountToPurchase);
    }

    // 이더 수량에 맞는 토큰 수량 Return (Frontend에서 실시간 계산용)
    function calculatePurchaseReturn(address contractAddress, uint256 ethAmount) external view onlyDeployed(contractAddress) returns (uint256) {
        ContractInfo storage info = contractInfo[contractAddress];
        // 1% fee 적용: deposit = ethAmount / 101 * 100
        uint256 adjustedEthAmount = ethAmount / (100 + _feeRate) * 100;
        return _bondingCurveContract.calculatePurchaseReturn(info.totalSupply, info.ethDepositBalance, adjustedEthAmount);
    }

    // Internal function to record transaction history
    function _recordTransaction(
        address user,
        address tokenAddress,
        string memory transactionType,
        uint256 ethAmount,
        uint256 tokenAmount,
        uint256 totalSupplyAfter,
        uint256 ethBalanceAfter
    ) internal {
        uint256 pricePerToken = tokenAmount > 0 ? (ethAmount * 10**18) / tokenAmount : 0;
        
        TransactionRecord memory newRecord = TransactionRecord({
            timestamp: block.timestamp,
            user: user,
            tokenAddress: tokenAddress,
            transactionType: transactionType,
            ethAmount: ethAmount,
            tokenAmount: tokenAmount,
            pricePerToken: pricePerToken,
            totalSupplyAfter: totalSupplyAfter,
            ethBalanceAfter: ethBalanceAfter,
            txHash: blockhash(block.number - 1), // Use previous block hash as approximation
            blockNumber: block.number
        });
        
        // Store in multiple mappings for efficient querying
        tokenTransactionHistory[tokenAddress].push(newRecord);
        userTransactionHistory[user].push(newRecord);
        allTransactions.push(newRecord);
        totalTransactionCount++;
        
        emit TransactionRecorded(user, tokenAddress, transactionType, ethAmount, tokenAmount, pricePerToken);
    }

    function buyToken(address contractAddress) public payable validGasPrice returns (uint256) {
        ContractInfo storage info = contractInfo[contractAddress];
        // contract sale not active (SNA)
        require(info.saleIsActive, "SNA");
        require(info.totalSupply < targetFundRasingAmount, "TFR");

        _tokenContract = IERC404(contractAddress);
        // eth
        uint256 deposit = msg.value;

        // 1% fee 차감
        deposit =  msg.value / (100 + _feeRate) * 100;
        require(deposit > 0, "Amount must be non-zero!");
        
        uint256 amount = _bondingCurveContract.calculatePurchaseReturn(info.totalSupply, info.ethDepositBalance, deposit);

        require(_tokenContract.balanceOf(address(this)) >= amount, "not enough balance");
    
        _tokenContract.transfer(msg.sender, amount);
        
        emit TokensPurchased(msg.sender, amount);

        // contract 누적 token 집계
        info.totalSupply += amount;
        // contract 누적 eth 집계
        info.ethDepositBalance += deposit;

        // Record transaction history
        _recordTransaction(
            msg.sender,
            contractAddress,
            "BUY",
            msg.value, // Original ETH amount before fee
            amount,
            info.totalSupply,
            info.ethDepositBalance
        );

        //event require(amount >= (8억 - contractsTotalSupply[contractAddress] + (+/- 오차))))) 허용, 토큰 남은건 DEX로, 이더는 15% LaunchPad로
        if (info.totalSupply >= targetFundRasingAmount) {
            // 여기서 실행할 경우 DEX 로 보내면 ETH가 소모되기 때문에 별도 함수에서 관리자가 수행하는게 맞음
            // contract 를 판매 종료하여 buy / sell 함수 호출을 revert 하도록 함.
            info.saleIsActive = false;
            emit SaleEnded(contractAddress, info.totalSupply, targetFundRasingAmount);                       
        }

        return amount;
    }

    function sellToken(address contractAddress, uint256 amount) validGasPrice public {
        ContractInfo storage info = contractInfo[contractAddress];
        require(info.saleIsActive, "SNA");
        require(amount > 0, "Amount must be non-zero!");

        _tokenContract = IERC404(contractAddress);

        require(_tokenContract.balanceOf(msg.sender) >= amount, "Sender does not have enough tokens to sell.");
        
        uint256 deposit = _bondingCurveContract.calculateSaleReturn(info.totalSupply, info.ethDepositBalance, amount);

        // 1% fee 차감
        deposit = (deposit * (100 - _feeRate)) / 100;

        info.ethDepositBalance -= deposit;
        info.totalSupply -= amount;

        // approve call first before using transferFrom
        _tokenContract.transferFrom(msg.sender, address(this), amount);        

        emit TokenSold(msg.sender, amount);

        // Record transaction history
        _recordTransaction(
            msg.sender,
            contractAddress,
            "SELL",
            deposit, // ETH amount after fee
            amount,
            info.totalSupply,
            info.ethDepositBalance
        );
        
        payable(msg.sender).transfer(deposit);
    }

    function getLaunchedContractCount() external view returns (uint256) {
        return totalContractCount;
    }

    function getLaunchedTokenContracts() external view returns (TokenInfo[] memory) {
        return launchedTokenContracts;
    }

    function getLaunchedTokenAddresses() external view returns (address[] memory) {
        address[] memory addresses = new address[](launchedTokenContracts.length);
        for (uint i = 0; i < launchedTokenContracts.length; i++) {
            addresses[i] = launchedTokenContracts[i].tokenAddress;
        }
        return addresses;
    }

    function getTokenInfo(uint256 index) external view returns (address tokenAddress, string memory symbol, string memory mainImage) {
        require(index < launchedTokenContracts.length, "Index out of bounds");
        TokenInfo memory tokenInfo = launchedTokenContracts[index];
        return (tokenInfo.tokenAddress, tokenInfo.symbol, tokenInfo.mainImage);
    }

    function getContractsDeployedBy(address deployer) external view returns (address[] memory) {
        return userDeployedContracts[deployer];
    }

    function sendEthToTreasury(uint256 amount) external onlyOwnerGroup {
        require(address(this).balance >= amount, "NEE");
        
        (bool success, ) = _treasuryAddress.call{value: amount}("");
        require(success, "ETF");
    }

    function setLiquidityProviderContract(address lpProviderAddress) external onlyOwnerGroup() {
        require(lpProviderAddress != address(0), "Invalid address");        
        _liquidityProviderContract = LiquidityProvider(payable(lpProviderAddress));
    }

    function addLiquidityETH(address contractAddress, uint256 tokenAmount, uint256 ethAmount) external onlyOwnerGroup {
        require(address(_liquidityProviderContract) != address(0), "LPCNA");
        require(contractInfo[contractAddress].exists, "CND");

        _liquidityProviderContract.addLiquidityETH(contractAddress, tokenAmount, ethAmount);
        emit SuppliedLP(contractAddress, tokenAmount, ethAmount);
    }

    // Real-time bonding curve calculations for UI - all calculations done on-chain
    
    // Calculate tokens for multiple ETH amounts at once
    function calculateTokensForEthAmountsBatch(
        address contractAddress, 
        uint256[] memory ethAmounts
    ) external view onlyDeployed(contractAddress) returns (uint256[] memory) {
        ContractInfo storage info = contractInfo[contractAddress];
        return _bondingCurveContract.calculatePurchaseReturnBatchWithFee(
            info.totalSupply,
            info.ethDepositBalance,
            ethAmounts,
            _feeRate
        );
    }
    
    // Quick calculation for common ETH amounts (0.001, 0.01, 0.1, 1 ETH)
    function calculateTokensQuickReference(address contractAddress) 
        external view onlyDeployed(contractAddress) 
        returns (
            uint256 tokens_for_001_eth,
            uint256 tokens_for_01_eth, 
            uint256 tokens_for_1_eth,
            uint256 tokens_for_10_eth
        ) {
        ContractInfo storage info = contractInfo[contractAddress];
        
        // Calculate with fee consideration
        uint256 deposit_001 = 1000000000000000 / (100 + _feeRate) * 100;    // 0.001 ETH with fee
        uint256 deposit_01 = 10000000000000000 / (100 + _feeRate) * 100;    // 0.01 ETH with fee  
        uint256 deposit_1 = 100000000000000000 / (100 + _feeRate) * 100;    // 0.1 ETH with fee
        uint256 deposit_10 = 1000000000000000000 / (100 + _feeRate) * 100;  // 1 ETH with fee
        
        tokens_for_001_eth = _bondingCurveContract.calculatePurchaseReturn(info.totalSupply, info.ethDepositBalance, deposit_001);
        tokens_for_01_eth = _bondingCurveContract.calculatePurchaseReturn(info.totalSupply, info.ethDepositBalance, deposit_01);
        tokens_for_1_eth = _bondingCurveContract.calculatePurchaseReturn(info.totalSupply, info.ethDepositBalance, deposit_1);
        tokens_for_10_eth = _bondingCurveContract.calculatePurchaseReturn(info.totalSupply, info.ethDepositBalance, deposit_10);
    }
    
    // Calculate exact tokens for any ETH amount (considering fees)
    function calculateExactTokensForEth(address contractAddress, uint256 ethAmount) 
        external view onlyDeployed(contractAddress) returns (uint256) {
        ContractInfo storage info = contractInfo[contractAddress];
        return _bondingCurveContract.calculatePurchaseReturnWithFee(
            info.totalSupply,
            info.ethDepositBalance, 
            ethAmount,
            _feeRate
        );
    }

    // Calculate ETH needed for specific token amount
    function calculateEthNeededForTokens(address contractAddress, uint256 tokenAmount) 
        external view onlyDeployed(contractAddress) returns (uint256) {
        ContractInfo storage info = contractInfo[contractAddress];
        uint256 ethNeeded = _bondingCurveContract.calculatePurchaseBalance(info.totalSupply, info.ethDepositBalance, tokenAmount);
        // Add fee back: if deposit = msgValue / 101 * 100, then msgValue = deposit * 101 / 100
        return ethNeeded * (100 + _feeRate) / 100;
    }

    // Get comprehensive bonding curve state for a token
    function getBondingCurveState(address contractAddress) 
        external view onlyDeployed(contractAddress) 
        returns (
            uint256 currentTotalSupply,
            uint256 currentEthBalance, 
            uint256 maxSupply,
            bool saleActive,
            uint8 feeRate,
            uint256 targetFunding,
            uint256 remainingToTarget
        ) {
        ContractInfo storage info = contractInfo[contractAddress];
        currentTotalSupply = info.totalSupply;
        currentEthBalance = info.ethDepositBalance;
        maxSupply = info.maxSupply;
        saleActive = info.saleIsActive;
        feeRate = _feeRate;
        targetFunding = targetFundRasingAmount;
        remainingToTarget = targetFundRasingAmount > info.totalSupply ? targetFundRasingAmount - info.totalSupply : 0;
    }

    // Transaction history query functions
    
    // Get transaction history for a specific token
    function getTokenTransactionHistory(address tokenAddress) external view returns (TransactionRecord[] memory) {
        return tokenTransactionHistory[tokenAddress];
    }
    
    // Get transaction history for a specific user
    function getUserTransactionHistory(address user) external view returns (TransactionRecord[] memory) {
        return userTransactionHistory[user];
    }
    
    // Get paginated transaction history for a token
    function getTokenTransactionHistoryPaginated(address tokenAddress, uint256 offset, uint256 limit) external view returns (TransactionRecord[] memory) {
        TransactionRecord[] storage records = tokenTransactionHistory[tokenAddress];
        uint256 length = records.length;
        
        if (offset >= length) {
            return new TransactionRecord[](0);
        }
        
        uint256 end = offset + limit;
        if (end > length) {
            end = length;
        }
        
        uint256 resultLength = end - offset;
        TransactionRecord[] memory result = new TransactionRecord[](resultLength);
        
        for (uint256 i = 0; i < resultLength; i++) {
            result[i] = records[length - 1 - offset - i]; // Return in reverse order (newest first)
        }
        
        return result;
    }
    
    // Get total transaction count for a token
    function getTokenTransactionCount(address tokenAddress) external view returns (uint256) {
        return tokenTransactionHistory[tokenAddress].length;
    }
    
    // Get total transaction count for a user
    function getUserTransactionCount(address user) external view returns (uint256) {
        return userTransactionHistory[user].length;
    }
    
    // Get recent transactions (last N transactions across all tokens)
    function getRecentTransactions(uint256 limit) external view returns (TransactionRecord[] memory) {
        uint256 totalCount = allTransactions.length;
        if (totalCount == 0 || limit == 0) {
            return new TransactionRecord[](0);
        }
        
        uint256 actualLimit = limit > totalCount ? totalCount : limit;
        TransactionRecord[] memory result = new TransactionRecord[](actualLimit);
        
        for (uint256 i = 0; i < actualLimit; i++) {
            result[i] = allTransactions[totalCount - 1 - i]; // Return in reverse order (newest first)
        }
        
        return result;
    }
    
    // Get transaction by index (from all transactions)
    function getTransactionByIndex(uint256 index) external view returns (TransactionRecord memory) {
        require(index < allTransactions.length, "Index out of bounds");
        return allTransactions[index];
    }

}
