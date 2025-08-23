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

    address private _treasuryAddress;
    uint256 public totalContractCount;
    address[] public launchedTokenContracts;
    mapping(address => address[]) public userDeployedContracts;

    uint256 targetFundRasingAmount = 800_000_000 * 10 ** 18;
    // buy / sell eth fee %
    uint8 public _feeRate = 1;

    mapping(address => ContractInfo) public contractInfo;

    // events
    event TokenPurchased(
        address indexed tokenAddress,
        address indexed buyer,
        uint256 amount,
        uint256 price
    );
    event TokenSold(
        address indexed tokenAddress,
        address indexed seller,
        uint256 amount,
        uint256 price
    );
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

    function createBioDiversityERC404Token(address tokenTreasuryAddress, uint256 maxSupply, string memory symbol, string memory name, uint256 taxPermil, 
        string memory imageURI_, string memory trait_type_, string[5] memory trait_values_, string[5] memory images_) public returns (address) {
        
        // 토큰 생성
        ERC404Token newContract = new ERC404Token(name, symbol, maxSupply, address(this), address(this), tokenTreasuryAddress, taxPermil, imageURI_, trait_type_, trait_values_, images_);
    
        address contractAddress = address(newContract); 
        
        // Already Deployed (AD)
        require(!contractInfo[contractAddress].exists, "AD");

        contractInfo[contractAddress] = ContractInfo({
            deployedBy: msg.sender,
            saleIsActive: true,
            maxSupply: maxSupply,
            totalSupply: 0,
            ethDepositBalance: 0,
            exists: true
        });

        totalContractCount++;
        launchedTokenContracts.push(contractAddress);
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

        // contract 누적 token 집계
        info.totalSupply += amount;
        // contract 누적 eth 집계
        info.ethDepositBalance += deposit;

        uint256 currentPrice = _bondingCurveContract.calculatePurchaseBalance(info.totalSupply, info.ethDepositBalance, 1 * (10 ** 18));

        emit TokenPurchased(contractAddress, msg.sender, amount, currentPrice);

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

        uint256 currentPrice = _bondingCurveContract.calculatePurchaseBalance(info.totalSupply, info.ethDepositBalance, 1 * (10 ** 18));

        emit TokenSold(contractAddress, msg.sender, amount, currentPrice);
        
        payable(msg.sender).transfer(deposit);
    }

    function getLaunchedContractCount() external view returns (uint256) {
        return totalContractCount;
    }

    function getLaunchedTokenContracts() external view returns (address[] memory) {
        return launchedTokenContracts;
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

}