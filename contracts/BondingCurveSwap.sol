// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libs/BancorFormula.sol";
import "./libs/MaxGasPrice.sol";

contract BondingCurveSwap is BancorFormula, MaxGasPrice {

    event Debug(string message, uint256 value);

    IERC20 private _token;
    uint256 private constant SCALE = 10**18;
    uint256 private constant INITIAL_TOKEN_SUPPLY = 3_690_287_251_496_824_536_722_139_764;
    uint256 private constant INITIAL_DEPOSIT_BALANCE = 1*SCALE;
    uint256 private _tokenSupply = INITIAL_TOKEN_SUPPLY;
    uint256 private _depositBalance = INITIAL_DEPOSIT_BALANCE;
    uint256 private _reserveRatio = 100000; // 10%

    constructor(address tokenAddress) {
        _token = IERC20(tokenAddress);
    }

    function getTokenSupply() public view returns (uint256) {
        return _tokenSupply - INITIAL_TOKEN_SUPPLY;
    }

    function getDepositBalance() public view returns (uint256) {
        return _depositBalance - INITIAL_DEPOSIT_BALANCE;
    }

    function calculatePurchaseReturn(uint256 deposit) public view returns (uint256) {
        return calculatePurchaseReturn(_tokenSupply, _depositBalance, uint32(_reserveRatio), deposit);
    }

    function calculateSaleReturn(uint256 amount) public view returns (uint256) {
        return calculateSaleReturn(_tokenSupply, _depositBalance, uint32(_reserveRatio), amount);
    }

    receive() external payable {
        purchase();
    }

    function purchase() validGasPrice public payable returns (uint256) {
        uint256 deposit = msg.value;

        require(deposit > 0, "Amount must be non-zero!");

        uint256 amount = calculatePurchaseReturn(deposit);

        _token.transfer(msg.sender, amount);

        _tokenSupply += amount;
        _depositBalance += deposit;

        return amount;
    }

    function sale(uint256 amount) validGasPrice public returns (uint256) {
        require(amount > 0, "Amount must be non-zero!");
        require(_token.balanceOf(msg.sender) >= amount, "Sender does not have enough tokens to sell.");
        require(_token.allowance(msg.sender, address(this)) >= amount, "Insufficient allowance");

        uint256 deposit = calculateSaleReturn(amount);

        _depositBalance -= deposit;
        _tokenSupply -= amount;

        _token.transferFrom(msg.sender, address(this), amount);
        payable(msg.sender).transfer(deposit);

        return deposit;
    }
}