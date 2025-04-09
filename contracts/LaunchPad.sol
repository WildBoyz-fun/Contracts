// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;


import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC404} from "./interfaces/IERC404.sol";
import {BioDiversityERC404Token} from "./BioDiversityERC404Token.sol";
import "./libs/MaxGasPrice.sol";
import {BondingCurveSwap} from "./libs/BondingCurveSwap.sol";

contract LaunchPad is Ownable, MaxGasPrice {

    // 생성시 deploy
    IERC404 private _tokenContract;
    // deploy 필요
    BondingCurveSwap private _bondingCurveSwapContract;
    uint256 public totalContractCount;
    // contract owner
    // mapping(address => address[]) public ownerToContracts;
    
    mapping(address => bool) public deployedContracts;
    // sale or not sale
    mapping(address => bool) public contractSaleStatus;
    
    // bonding curve parameters
    mapping(address => uint256) private contractsTotalSupply;
    mapping(address => uint256) private contractsEthDepositBalance;

    // events
    event TokensPurchased(address indexed buyer, uint256 amount);
    event SaleStarted(address indexed contractAddress);
    event SaleEnded(address indexed contractAddress);    
    event ContractDeployed(
        address indexed contractAddress,
        address indexed deployedBy,
        string symbolName
    );

    constructor (address bondingCurveContract) Ownable(msg.sender) MaxGasPrice(msg.sender) BondingCurveSwap(msg.sender) {

        _bondingCurveSwapContract = BondingCurveSwap(bondingCurveContract);
    }

    function createBioDiversityERC404Token(uint256 totalSupply, string memory symbol, string memory name, address owner, uint256 taxPermil) public returns (address, address) {

        // bondingCurve Parameter
        
        // ERC404 Token mint to launchPad
        // new LaunchPadTreasury Contract?? (owners, eth, erc20token, deposit/withdraw, multisig strategy, earning(token exit 75~80%))
        TokenTreasury tokenTreasury = new TokenTreasury();
        BioDiversityERC404Token newContract = new BioDiversityERC404Token(name, symbol, totalSupply, owner, address(this), address(tokenTreasury), taxPermil, images..., taxOn / taxOff);
        
        // Store the contract address
        address contractAddress = address(newContract);

        // Already Deployed (AD)
        require(!deployedContracts[contractAddress], "AD");

        deployedContracts[contractAddress] = true;
        
        totalContractCount++;

        // contract별 token 공급량
        contractsTotalSupply[contractAddress] = 0;
        // contract별 eth 예치양
        contractsEthDepositBalance[contractAddress] = 0;

        contractSaleStatus[contractAddress] = true;

        // Emit event for tracking
        emit ContractDeployed(contractAddress, msg.sender, symbol);

        return contractAddress;
    }

     function startSale(address contractAddress) external onlyOwner {
        // contract not deployed
        require(deployedContracts[contractAddress], "CND");
        // contract not sale (NSA)
        require(!contractSaleStatus[contractAddress], "NSA");

        contractSaleStatus[contractAddress] = true;
    
        emit SaleStarted(contractAddress);
    }


    // call endSale with bondingCurve
    function endSale(address contractAddress) external onlyOwner {
        // contract not deployed
        require(deployedContracts[contractAddress], "CND");
        // contract sale active (SA)
        require(contractSaleStatus[contractAddress], "SA");

        contractSaleStatus[contractAddress] = false;
    
        emit SaleEnded(contractAddress);
    }

    function getContractSaleStatus(address contractAddress) internal returns (bool) {
        
        require(deployedContracts[contractAddress], "CND");
        
        return contractSaleStatus[contractAddress];
    }

    function buyToken(address contractAddress) public payable validGasPrice returns (uint256) {
        // contract sale not active (SNA)
        require(getContractSaleStatus(contractAddress), "SNA");

        _tokenContract = IERC404(contractAddress);
        // eth
        uint256 deposit = msg.value;

        require(deposit > 0, "Amount must be non-zero!");

        //fee계산 1%차감 deposit = deposit - fee
        uint256 amount = _bondingCurveSwapContract.calculatePurchaseReturn(contractsTotalSupply[contractAddress], contractsEthDepositBalance[contractAddress], deposit);

        //require(amount >= (8억 - contractsTotalSupply[contractAddress]) + @(오차))) 실패처리
        
        require(_tokenContract.balanceOf(address(this)) >= amount, "not enough balance");

        _tokenContract.erc20TransferFrom(address(this), msg.sender, amount);
        
        emit TokensPurchased(msg.sender, amount);        

        // contract 누적 token 집계
        contractsTotalSupply[contractAddress] += amount;
        // contract 누적 eth 집계
        contractsEthDepositBalance[contractAddress] += deposit;

        // eth fee??
        // contractsTotalSupply[contractAddress] >  8억개 판매시 중단 (10억개 발행)
        // 모집 event 발행 

        // to do implement
        // bonding curve 달성 시 이벤트 필요 (uniswap) -  + contract marking // block to buy / sell
        // call sendTokenToUniSwap
        // TokenTreasury tax on


        return amount;
    }

    function tokenPreview (address contractAddress, uint256 tokenAmount) public {
        // implement bondingCurve 남은 토큰량 계산
    }

    function sellToken(address contractAddress, uint256 amount) validGasPrice public {

        require(getContractSaleStatus(contractAddress), "SNA");
        require(amount > 0, "Amount must be non-zero!");

        _tokenContract = IERC404(contractAddress);
        
        require(_tokenContract.balanceOf(msg.sender) >= amount, "Sender does not have enough tokens to sell.");
        require(_tokenContract.allowance(msg.sender, address(this)) >= amount, "Insufficient allowance");

        uint256 deposit = _bondingCurveSwapContract.calculateSaleReturn(contractsTotalSupply[contractAddress], contractsEthDepositBalance[contractAddress], amount);

        
        contractsEthDepositBalance[contractAddress] -= deposit;
        contractsTotalSupply[contractAddress] -= amount;

        _tokenContract.erc20TransferFrom(msg.sender, address(this), amount);

        // fee 차감 구현 필요
        // //fee계산 1%차감 deposit = deposit - fee
        payable(msg.sender).transfer(deposit);
    }

    function getLaunchedContractCount() public returns (uint256) {
        return totalContractCount;
    }

    // function checkContractState(address contractAddress) public returns (bool) {
    //     return false;
    // }

    // function getActiveContractCount() public returns (uint256) {

    //     return 100;
    // }


}