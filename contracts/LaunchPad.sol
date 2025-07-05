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

    address private _treasuryAddress;
    uint256 public totalContractCount;
    uint256 targetFundRasingAmount = 800_000_000 * 10 ** 18;
    // buy / sell eth fee %
    uint8 public _feeRate = 1;

    mapping(address => bool) public deployedContracts;
    // sale or not sale
    mapping(address => bool) public contractSaleStatus;

    // bonding curve parameters
    mapping(address => uint256) private contractsTotalSupply;
    mapping(address => uint256) private contractsEthDepositBalance;

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

    modifier onlyDeployed(address contractAddress) {
        require(deployedContracts[contractAddress], "CND");
        _;
    }

    modifier onlyOwnerGroup (){
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

    function createBioDiversityERC404Token(address tokenTreasuryAddress, uint256 totalSupply, string memory symbol, string memory name, uint256 taxPermil, 
        string memory imageURI_, string memory trait_type_, string[5] memory trait_values_, string[5] memory images_) public returns (address) {
        
        // 토큰 생성
        ERC404Token newContract = new ERC404Token(name, symbol, totalSupply, address(this), address(this), tokenTreasuryAddress, taxPermil, imageURI_, trait_type_, trait_values_, images_);
    
        address contractAddress = address(newContract); 
        
        // Already Deployed (AD)
        require(!deployedContracts[contractAddress], "AD");

        deployedContracts[contractAddress] = true;
        contractSaleStatus[contractAddress] = true;
        totalContractCount++;
        
        // bondingCurveContract contract별 token 공급량
        contractsTotalSupply[contractAddress] = 0;
        // bondingCurveContract contract별 eth 예치양
        contractsEthDepositBalance[contractAddress] = 0;

        // Emit event for tracking
        emit ContractDeployed(contractAddress, msg.sender, symbol);
    
        return (contractAddress);
    }

    function getContractEthBalance(address contractAddress ) external view returns (uint256) {
        return contractsEthDepositBalance[contractAddress];
    }

    function getContractTotalSupplyBalance(address contractAddress ) external view returns (uint256) {
        return contractsTotalSupply[contractAddress];
    }

    function changeContractSaleStatus(address contractAddress) public onlyOwnerGroup onlyDeployed(contractAddress) returns (bool) {
        contractSaleStatus[contractAddress] = !contractSaleStatus[contractAddress];    
        return contractSaleStatus[contractAddress];
    }

    function getContractSaleStatus(address contractAddress) public view onlyDeployed(contractAddress) returns (bool) {
        return contractSaleStatus[contractAddress];
    }

    // 사고싶은 토큰 수량에 맞는 이더 수량 Return
    function calculatePurchaseBalance(address contractAddress, uint256 tokenAmountToPurchase) external view onlyDeployed(contractAddress) returns (uint256) {
        return _bondingCurveContract.calculatePurchaseBalance(contractsTotalSupply[contractAddress], contractsEthDepositBalance[contractAddress], tokenAmountToPurchase);
    }

    function buyToken(address contractAddress) public payable validGasPrice returns (uint256) {
        // contract sale not active (SNA)
        require(getContractSaleStatus(contractAddress), "SNA");
        require(contractsTotalSupply[contractAddress] < targetFundRasingAmount, "TFR");

        _tokenContract = IERC404(contractAddress);
        // eth
        uint256 deposit = msg.value;

        // 1% fee 차감
        deposit =  msg.value / (100 + _feeRate) * 100;
        require(deposit > 0, "Amount must be non-zero!");
        
        uint256 amount = _bondingCurveContract.calculatePurchaseReturn(contractsTotalSupply[contractAddress], contractsEthDepositBalance[contractAddress], deposit);

        require(_tokenContract.balanceOf(address(this)) >= amount, "not enough balance");
    
        _tokenContract.transfer(msg.sender, amount);
        
        emit TokensPurchased(msg.sender, amount);

        // contract 누적 token 집계
        contractsTotalSupply[contractAddress] += amount;
        // contract 누적 eth 집계
        contractsEthDepositBalance[contractAddress] += deposit;

        //event require(amount >= (8억 - contractsTotalSupply[contractAddress] + (+/- 오차))))) 허용, 토큰 남은건 DEX로, 이더는 15% LaunchPad로
        if (contractsTotalSupply[contractAddress] >= targetFundRasingAmount) {
            // 여기서 실행할 경우 DEX 로 보내면 ETH가 소모되기 때문에 별도 함수에서 관리자가 수행하는게 맞음
            // contract 를 판매 종료하여 buy / sell 함수 호출을 revert 하도록 함.
            contractSaleStatus[contractAddress] = !contractSaleStatus[contractAddress];
            emit SaleEnded(contractAddress, contractsTotalSupply[contractAddress], targetFundRasingAmount);                       
        }

        return amount;
    }

    function sellToken(address contractAddress, uint256 amount) validGasPrice public {

        require(getContractSaleStatus(contractAddress), "SNA");
        require(amount > 0, "Amount must be non-zero!");

        _tokenContract = IERC404(contractAddress);

        require(_tokenContract.balanceOf(msg.sender) >= amount, "Sender does not have enough tokens to sell.");
        
        uint256 deposit = _bondingCurveContract.calculateSaleReturn(contractsTotalSupply[contractAddress], contractsEthDepositBalance[contractAddress], amount);

        // 1% fee 차감
        deposit = (deposit * (100 - _feeRate)) / 100;

        contractsEthDepositBalance[contractAddress] -= deposit;
        contractsTotalSupply[contractAddress] -= amount;

        // approve call first before using transferFrom
        _tokenContract.transferFrom(msg.sender, address(this), amount);        

        emit TokenSold(msg.sender, amount);
        
        payable(msg.sender).transfer(deposit);
    }

    function getLaunchedContractCount() external view returns (uint256) {
        return totalContractCount;
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
        require(deployedContracts[contractAddress], "CND");

        _liquidityProviderContract.addLiquidityETH(contractAddress, tokenAmount, ethAmount);
        emit SuppliedLP(contractAddress, tokenAmount, ethAmount);
    }

}