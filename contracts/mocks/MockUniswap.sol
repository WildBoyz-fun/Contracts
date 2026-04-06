// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Simple ERC20 mock for LP tokens
contract MockLPToken is ERC20 {
    constructor() ERC20("Uniswap V2 LP", "UNI-V2") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockUniswapV2Factory {
    mapping(address => mapping(address => address)) public getPair;
    mapping(address => MockLPToken) public pairTokens;

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        // If pair already exists, return it
        if (getPair[tokenA][tokenB] != address(0)) {
            return getPair[tokenA][tokenB];
        }

        // Deploy a real ERC20 as LP token
        MockLPToken lpToken = new MockLPToken();
        pair = address(lpToken);
        pairTokens[pair] = lpToken;

        getPair[tokenA][tokenB] = pair;
        getPair[tokenB][tokenA] = pair;
    }

    function mintLP(address pair, address to, uint256 amount) external {
        MockLPToken(pair).mint(to, amount);
    }
}

contract MockWETH is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH") {}

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }

    receive() external payable {
        _mint(msg.sender, msg.value);
    }
}

contract MockUniswapV2Router {
    address public factory;
    address public WETH;

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity) {
        require(deadline >= block.timestamp, "Expired");

        amountToken = amountTokenDesired;
        amountETH = msg.value;
        liquidity = amountETH; // simplified: 1 LP token per ETH

        // Verify slippage bounds
        require(amountToken >= amountTokenMin, "Insufficient token amount");
        require(amountETH >= amountETHMin, "Insufficient ETH amount");

        // Create pair if not exists, then mint LP tokens to `to`
        address pair = MockUniswapV2Factory(factory).createPair(token, WETH);
        MockUniswapV2Factory(factory).mintLP(pair, to, liquidity);

        return (amountToken, amountETH, liquidity);
    }

    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts)
    {
        amounts = new uint[](path.length);
        amounts[0] = msg.value;
        amounts[1] = msg.value; // Simulate 1:1 swap for testing
        return amounts;
    }
}
