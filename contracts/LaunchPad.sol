// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// import {IERC404} from "./libs/ERC404/interfaces/IERC404.sol";
// import {ERC404Token} from "./ERC404Token.sol";
import { MyToken } from "./libs/sample/MyToken.sol";
import "./libs/MaxGasPrice.sol";
import "./BondingCurve.sol";
import "./TokenTreasury.sol";


contract LaunchPad is MaxGasPrice {
    IERC20 private _tokenContract;

    BondingCurve private _bondingCurveContract;
    
    uint256 public totalContractCount;
    uint256 targetFundRasingAmount = 800_000_000 * 10 ** 18;

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

    event TokenTreasuryContractDeployed(
        address indexed contractAddress
    );


    modifier onlyDeployed(address contractAddress) {
        require(deployedContracts[contractAddress], "CND");
        _;
    }

    constructor (address bondingCurveContract) MaxGasPrice(msg.sender) {
        _bondingCurveContract = BondingCurve(bondingCurveContract);
    }

    function createTokenTreasury(address[] memory tokenOwners) private returns (address) {
        TokenTreasury tokenTreasury = new TokenTreasury(tokenOwners);
        return address(tokenTreasury);
    }

    // function createBioDiversityERC404Token(address[] memory tokenTreasuryOwners, uint256 totalSupply, string memory symbol, string memory name, address owner, uint256 taxPermil, 
    //     string memory imageURI_, string memory trait_type_, string[5] memory trait_values_, string[5] memory images_) public returns (address, address) {
    function createBioDiversityERC404Token(string memory name, string memory symbol, uint256 totalSupply) public returns (address) {
                
        // 토큰 트레저리 생성
        // address tokenTreasuryAddress = createTokenTreasury(tokenTreasuryOwners);
        // 토큰 생성
        // ERC404Token newContract = new ERC404Token(name, symbol, totalSupply, owner, address(this), tokenTreasuryAddress, taxPermil, imageURI_, trait_type_, trait_values_, images_);
        MyToken newContract = new MyToken(name, symbol, totalSupply);
        address contractAddress = address(newContract); 
        
        // Already Deployed (AD)
        require(!deployedContracts[contractAddress], "AD");

        deployedContracts[contractAddress] = true;
        // contractSaleStatus[contractAddress] = true;
        totalContractCount++;
        
        
        // bondingCurveContract contract별 token 공급량
        contractsTotalSupply[contractAddress] = 0;
        // bondingCurveContract contract별 eth 예치양
        contractsEthDepositBalance[contractAddress] = 0;

        
        // Emit event for tracking
        emit ContractDeployed(contractAddress, msg.sender, symbol);
        // emit TokenTreasuryContractDeployed(tokenTreasuryAddress);

        return (contractAddress);
    }

     function startSale(address contractAddress) external onlyOwner onlyDeployed(contractAddress){
        // contract not sale (NSA)
        require(!contractSaleStatus[contractAddress], "NSA");

        contractSaleStatus[contractAddress] = true;

        emit SaleStarted(contractAddress);
    }


    // call endSale with bondingCurve
    function endSale(address contractAddress) public onlyOwner onlyDeployed(contractAddress){
        
        // contract sale active (SA)
        require(contractSaleStatus[contractAddress], "SA");

        contractSaleStatus[contractAddress] = false;

        emit SaleEnded(contractAddress);
    }

    function getContractSaleStatus(address contractAddress) external view onlyDeployed(contractAddress) returns (bool) {
        return contractSaleStatus[contractAddress];
    }

    function calculatePurchaseBalance(address contractAddress, uint256 tokenAmountToPurchase) external view onlyDeployed(contractAddress) returns (uint256) {
        return _bondingCurveContract.calculatePurchaseBalance(contractsTotalSupply[contractAddress], contractsEthDepositBalance[contractAddress], tokenAmountToPurchase);
    }

    function buyToken(address contractAddress) public payable validGasPrice returns (uint256) {
        // contract sale not active (SNA)
        // require(getContractSaleStatus(contractAddress), "SNA");
        require(contractsTotalSupply[contractAddress] < targetFundRasingAmount, "TFR");

        _tokenContract = IERC20(contractAddress);
        // eth
        uint256 deposit = msg.value;

        require(deposit > 0, "Amount must be non-zero!");

        //fee계산 1%차감 deposit = deposit - fee
        uint256 amount = _bondingCurveContract.calculatePurchaseReturn(contractsTotalSupply[contractAddress], contractsEthDepositBalance[contractAddress], deposit);

        //require(amount >= (8억 - contractsTotalSupply[contractAddress]) + @(오차))) 실패처리

        require(_tokenContract.balanceOf(address(this)) >= amount, "not enough balance");

        // _tokenContract.erc20TransferFrom(address(this), msg.sender, amount);
        // _tokenContract.approve(msg.sender, amount);
        _tokenContract.transfer(msg.sender, amount);
        
        emit TokensPurchased(msg.sender, amount);

        // contract 누적 token 집계
        contractsTotalSupply[contractAddress] += amount;
        // contract 누적 eth 집계
        contractsEthDepositBalance[contractAddress] += deposit;

        if (contractsTotalSupply[contractAddress] >= targetFundRasingAmount) {
            // endSale(contractAddress);
            // emit SaleEnded(contractAddress);
        }

        return amount;
    }

    function sellToken(address contractAddress, uint256 amount) validGasPrice public {

        // require(getContractSaleStatus(contractAddress), "SNA");
        require(amount > 0, "Amount must be non-zero!");

        _tokenContract = IERC20(contractAddress);

        require(_tokenContract.balanceOf(msg.sender) >= amount, "Sender does not have enough tokens to sell.");
        // require(_tokenContract.allowance(msg.sender, address(this)) >= amount, "Insufficient allowance");

        uint256 deposit = _bondingCurveContract.calculateSaleReturn(contractsTotalSupply[contractAddress], contractsEthDepositBalance[contractAddress], amount);

        contractsEthDepositBalance[contractAddress] -= deposit;
        contractsTotalSupply[contractAddress] -= amount;

    
        _tokenContract.transferFrom(msg.sender, address(this), amount);        
        // _tokenContract.transfer(address(this), amount);

        // fee 차감 구현 필요
        // //fee계산 1%차감 deposit = deposit - fee
        payable(msg.sender).transfer(deposit);
    }

    function getLaunchedContractCount() public view returns (uint256) {
        return totalContractCount;
    }


}