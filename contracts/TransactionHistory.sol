// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface ITransactionHistory {
    struct TransactionRecord {
        uint256 timestamp;
        address user;
        address tokenAddress;
        string transactionType;
        uint256 ethAmount;
        uint256 tokenAmount;
        uint256 pricePerToken;
        uint256 totalSupplyAfter;
        uint256 ethBalanceAfter;
        bytes32 txHash;
        uint256 blockNumber;
    }

    function recordTransaction(
        address user,
        address tokenAddress,
        string calldata transactionType,
        uint256 ethAmount,
        uint256 tokenAmount,
        uint256 totalSupplyAfter,
        uint256 ethBalanceAfter
    ) external;

    function getTokenTransactionHistory(address tokenAddress) external view returns (TransactionRecord[] memory);

    function getUserTransactionHistory(address user) external view returns (TransactionRecord[] memory);

    function getTokenTransactionHistoryPaginated(
        address tokenAddress,
        uint256 offset,
        uint256 limit
    ) external view returns (TransactionRecord[] memory);

    function getTokenTransactionCount(address tokenAddress) external view returns (uint256);

    function getUserTransactionCount(address user) external view returns (uint256);

    function getRecentTransactions(uint256 limit) external view returns (TransactionRecord[] memory);

    function getTransactionByIndex(uint256 index) external view returns (TransactionRecord memory);

    function totalTransactions() external view returns (uint256);
}

error NotAdmin();
error LaunchPadAlreadySet();
error LaunchPadNotSet();
error NotLaunchPad();
error ZeroAddress();
error TransactionIndexOutOfBounds();

contract TransactionHistory is ITransactionHistory {
    address public admin;
    address public launchPad;

    mapping(address => TransactionRecord[]) private _tokenTransactionHistory;
    mapping(address => TransactionRecord[]) private _userTransactionHistory;
    TransactionRecord[] private _allTransactions;

    event TransactionRecorded(
        address indexed user,
        address indexed tokenAddress,
        string transactionType,
        uint256 ethAmount,
        uint256 tokenAmount,
        uint256 pricePerToken
    );

    constructor(address admin_) {
        if (admin_ == address(0)) {
            revert ZeroAddress();
        }
        admin = admin_;
    }

    function setLaunchPad(address launchPad_) external {
        if (msg.sender != admin) {
            revert NotAdmin();
        }
        if (launchPad_ == address(0)) {
            revert ZeroAddress();
        }
        if (launchPad != address(0)) {
            revert LaunchPadAlreadySet();
        }
        launchPad = launchPad_;
    }

    function transferAdmin(address newAdmin) external {
        if (msg.sender != admin) {
            revert NotAdmin();
        }
        if (newAdmin == address(0)) {
            revert ZeroAddress();
        }
        admin = newAdmin;
    }

    modifier onlyLaunchPad() {
        if (launchPad == address(0)) {
            revert LaunchPadNotSet();
        }
        if (msg.sender != launchPad) {
            revert NotLaunchPad();
        }
        _;
    }

    function recordTransaction(
        address user,
        address tokenAddress,
        string calldata transactionType,
        uint256 ethAmount,
        uint256 tokenAmount,
        uint256 totalSupplyAfter,
        uint256 ethBalanceAfter
    ) external onlyLaunchPad {
        uint256 pricePerToken = tokenAmount > 0 ? (ethAmount * 1e18) / tokenAmount : 0;

        TransactionRecord memory record = TransactionRecord({
            timestamp: block.timestamp,
            user: user,
            tokenAddress: tokenAddress,
            transactionType: transactionType,
            ethAmount: ethAmount,
            tokenAmount: tokenAmount,
            pricePerToken: pricePerToken,
            totalSupplyAfter: totalSupplyAfter,
            ethBalanceAfter: ethBalanceAfter,
            txHash: blockhash(block.number - 1),
            blockNumber: block.number
        });

        _tokenTransactionHistory[tokenAddress].push(record);
        _userTransactionHistory[user].push(record);
        _allTransactions.push(record);

        emit TransactionRecorded(user, tokenAddress, transactionType, ethAmount, tokenAmount, pricePerToken);
    }

    function getTokenTransactionHistory(address tokenAddress)
        external
        view
        override
        returns (TransactionRecord[] memory)
    {
        return _tokenTransactionHistory[tokenAddress];
    }

    function getUserTransactionHistory(address user)
        external
        view
        override
        returns (TransactionRecord[] memory)
    {
        return _userTransactionHistory[user];
    }

    function getTokenTransactionHistoryPaginated(
        address tokenAddress,
        uint256 offset,
        uint256 limit
    ) external view override returns (TransactionRecord[] memory) {
        TransactionRecord[] storage records = _tokenTransactionHistory[tokenAddress];
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
            result[i] = records[length - 1 - offset - i];
        }

        return result;
    }

    function getTokenTransactionCount(address tokenAddress) external view override returns (uint256) {
        return _tokenTransactionHistory[tokenAddress].length;
    }

    function getUserTransactionCount(address user) external view override returns (uint256) {
        return _userTransactionHistory[user].length;
    }

    function getRecentTransactions(uint256 limit) external view override returns (TransactionRecord[] memory) {
        uint256 totalCount = _allTransactions.length;
        if (totalCount == 0 || limit == 0) {
            return new TransactionRecord[](0);
        }

        uint256 actualLimit = limit > totalCount ? totalCount : limit;
        TransactionRecord[] memory result = new TransactionRecord[](actualLimit);

        for (uint256 i = 0; i < actualLimit; i++) {
            result[i] = _allTransactions[totalCount - 1 - i];
        }

        return result;
    }

    function getTransactionByIndex(uint256 index) external view override returns (TransactionRecord memory) {
        if (index >= _allTransactions.length) {
            revert TransactionIndexOutOfBounds();
        }
        return _allTransactions[index];
    }

    function totalTransactions() external view override returns (uint256) {
        return _allTransactions.length;
    }
}
