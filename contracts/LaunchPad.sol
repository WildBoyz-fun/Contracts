// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC404} from "./libs/ERC404/interfaces/IERC404.sol";
import {ERC404Token} from "./ERC404Token.sol";
import "./libs/MaxGasPrice.sol";
import "./BondingCurve.sol";
import "./LiquidityProvider.sol";
import {ITransactionHistory} from "./TransactionHistory.sol";
import {LaunchPadTokenFactory} from "./LaunchPadTokenFactory.sol";

import {IOwnerGroupContract} from "./libs/IOwnerGroupContract.sol";

error ContractNotDeployed();
error NotOwnerGroup();
error InvalidCreationFee();
error FeeTransferFailed();
error ContractAlreadyDeployed();
error SaleNotActive();
error TargetReached();
error AmountZero();
error InsufficientLaunchPadBalance();
error InsufficientUserBalance();
error ZeroAddress();

contract LaunchPad is MaxGasPrice {
    IERC404 private _tokenContract;
    BondingCurve private _bondingCurveContract;
    IOwnerGroupContract private _ownerGroupContract;    
    LiquidityProvider private _liquidityProviderContract;
    LaunchPadTokenFactory private _tokenFactory;
    ITransactionHistory private _transactionHistory;

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

    uint256 public constant TARGET_FUNDRAISING_AMOUNT = 800_000_000 * 10 ** 18;
    // buy / sell eth fee %
    uint8 public constant FEE_RATE = 1;

    uint256 private constant _DEFAULT_MAX_SUPPLY = 1_000_000_000 * 10 ** 18;

    mapping(address => ContractInfo) public contractInfo;
    
    // Transaction history storage
    // events
    event TokensPurchased(address indexed buyer, uint256 amount);
    event TokenSold(address indexed buyer, uint256 amount);
    event ContractDeployed(
        address indexed contractAddress,
        address indexed deployedBy,
        string symbolName
    );
    event Received(address sender, uint amount);
    event SaleEnded(address contractAddress, uint256 contractTotalSupply, uint256 targetFundRasingAmount);
    event SuppliedLP(
        address indexed contractAddress,
        uint256 tokenAmount,
        uint256 ethAmount
    );
    modifier onlyDeployed(address contractAddress) {
        if (!contractInfo[contractAddress].exists) {
            revert ContractNotDeployed();
        }
        _;
    }

    modifier onlyOwnerGroup () {
        if (!_ownerGroupContract.isOwner(msg.sender)) {
            revert NotOwnerGroup();
        }
        _;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    constructor (
        address treasuryAddress,
        address bondingCurveContract,
        address ownerGroupContract,
        address transactionHistoryContract,
        address tokenFactoryContract
    ) MaxGasPrice(msg.sender) {
        if (
            treasuryAddress == address(0) ||
            bondingCurveContract == address(0) ||
            ownerGroupContract == address(0) ||
            transactionHistoryContract == address(0) ||
            tokenFactoryContract == address(0)
        ) {
            revert ZeroAddress();
        }

        _treasuryAddress = treasuryAddress;
        _bondingCurveContract = BondingCurve(bondingCurveContract);
        _ownerGroupContract = IOwnerGroupContract(ownerGroupContract);
        _transactionHistory = ITransactionHistory(transactionHistoryContract);
        _tokenFactory = LaunchPadTokenFactory(tokenFactoryContract);
    }

    function bondingCurveAddress() external view returns (address) {
        return address(_bondingCurveContract);
    }

    uint256 private constant _TOKEN_CREATION_FEE = 0.001 ether;

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
        if (msg.value != _TOKEN_CREATION_FEE) {
            revert InvalidCreationFee();
        }

        (bool feeTransferred, ) = _treasuryAddress.call{value: msg.value}("");
        if (!feeTransferred) {
            revert FeeTransferFailed();
        }

        // 토큰 생성
        address contractAddress = _tokenFactory.deployToken(
            symbol,
            name,
            tokenTreasuryAddress,
            taxPermil,
            imageURI_,
            trait_type_,
            trait_values_,
            images_
        );
        
        // Already Deployed (AD)
        if (contractInfo[contractAddress].exists) {
            revert ContractAlreadyDeployed();
        }

        contractInfo[contractAddress] = ContractInfo({
            deployedBy: msg.sender,
            saleIsActive: true,
            maxSupply: _DEFAULT_MAX_SUPPLY,
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

    function changeContractSaleStatus(address contractAddress) public onlyOwnerGroup onlyDeployed(contractAddress) returns (bool) {
        contractInfo[contractAddress].saleIsActive = !contractInfo[contractAddress].saleIsActive;
        return contractInfo[contractAddress].saleIsActive;
    }

    function _recordTransaction(
        address user,
        address tokenAddress,
        string memory transactionType,
        uint256 ethAmount,
        uint256 tokenAmount,
        uint256 totalSupplyAfter,
        uint256 ethBalanceAfter
    ) internal {
        _transactionHistory.recordTransaction(
            user,
            tokenAddress,
            transactionType,
            ethAmount,
            tokenAmount,
            totalSupplyAfter,
            ethBalanceAfter
        );
    }

    function buyToken(address contractAddress) public payable validGasPrice returns (uint256) {
        ContractInfo storage info = contractInfo[contractAddress];
        // contract sale not active (SNA)
        if (!info.saleIsActive) {
            revert SaleNotActive();
        }
        if (info.totalSupply >= TARGET_FUNDRAISING_AMOUNT) {
            revert TargetReached();
        }

        _tokenContract = IERC404(contractAddress);
        // eth
        uint256 deposit = msg.value;

        // 1% fee 차감
        deposit =  msg.value / (100 + FEE_RATE) * 100;
        if (deposit == 0) {
            revert AmountZero();
        }
        
        uint256 amount = _bondingCurveContract.calculatePurchaseReturn(info.totalSupply, info.ethDepositBalance, deposit);

        if (_tokenContract.balanceOf(address(this)) < amount) {
            revert InsufficientLaunchPadBalance();
        }
    
        _tokenContract.transfer(msg.sender, amount);
        
        emit TokensPurchased(msg.sender, amount);

        // contract 누적 token 집계
        info.totalSupply += amount;
        // contract 누적 eth 집계
        info.ethDepositBalance += deposit;

        _recordTransaction(
            msg.sender,
            contractAddress,
            "BUY",
            msg.value,
            amount,
            info.totalSupply,
            info.ethDepositBalance
        );

        //event require(amount >= (8억 - contractsTotalSupply[contractAddress] + (+/- 오차))))) 허용, 토큰 남은건 DEX로, 이더는 15% LaunchPad로
        if (info.totalSupply >= TARGET_FUNDRAISING_AMOUNT) {
            // 여기서 실행할 경우 DEX 로 보내면 ETH가 소모되기 때문에 별도 함수에서 관리자가 수행하는게 맞음
            // contract 를 판매 종료하여 buy / sell 함수 호출을 revert 하도록 함.
            info.saleIsActive = false;
            emit SaleEnded(contractAddress, info.totalSupply, TARGET_FUNDRAISING_AMOUNT);                       
        }

        return amount;
    }

    function sellToken(address contractAddress, uint256 amount) validGasPrice public {
        ContractInfo storage info = contractInfo[contractAddress];
        if (!info.saleIsActive) {
            revert SaleNotActive();
        }
        if (amount == 0) {
            revert AmountZero();
        }

        _tokenContract = IERC404(contractAddress);

        if (_tokenContract.balanceOf(msg.sender) < amount) {
            revert InsufficientUserBalance();
        }
        
        uint256 deposit = _bondingCurveContract.calculateSaleReturn(info.totalSupply, info.ethDepositBalance, amount);

        // 1% fee 차감
        deposit = (deposit * (100 - FEE_RATE)) / 100;

        info.ethDepositBalance -= deposit;
        info.totalSupply -= amount;

        // approve call first before using transferFrom
        _tokenContract.transferFrom(msg.sender, address(this), amount);        

        emit TokenSold(msg.sender, amount);

        _recordTransaction(
            msg.sender,
            contractAddress,
            "SELL",
            deposit,
            amount,
            info.totalSupply,
            info.ethDepositBalance
        );

        payable(msg.sender).transfer(deposit);
    }

    function getTokenTransactionHistory(address tokenAddress)
        external
        view
        returns (ITransactionHistory.TransactionRecord[] memory)
    {
        return _transactionHistory.getTokenTransactionHistory(tokenAddress);
    }

    function getUserTransactionHistory(address user)
        external
        view
        returns (ITransactionHistory.TransactionRecord[] memory)
    {
        return _transactionHistory.getUserTransactionHistory(user);
    }

    function getTokenTransactionHistoryPaginated(address tokenAddress, uint256 offset, uint256 limit)
        external
        view
        returns (ITransactionHistory.TransactionRecord[] memory)
    {
        return _transactionHistory.getTokenTransactionHistoryPaginated(tokenAddress, offset, limit);
    }

    function getTokenTransactionCount(address tokenAddress) external view returns (uint256) {
        return _transactionHistory.getTokenTransactionCount(tokenAddress);
    }

    function getUserTransactionCount(address user) external view returns (uint256) {
        return _transactionHistory.getUserTransactionCount(user);
    }

    function getRecentTransactions(uint256 limit)
        external
        view
        returns (ITransactionHistory.TransactionRecord[] memory)
    {
        return _transactionHistory.getRecentTransactions(limit);
    }

    function getTransactionByIndex(uint256 index)
        external
        view
        returns (ITransactionHistory.TransactionRecord memory)
    {
        return _transactionHistory.getTransactionByIndex(index);
    }

    function getTotalTransactionCount() external view returns (uint256) {
        return _transactionHistory.totalTransactions();
    }

}
