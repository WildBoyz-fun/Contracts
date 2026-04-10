// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Simple ERC20 mock for LP tokens, also holds reserves
contract MockLPToken is ERC20 {
    address public token0;
    address public token1;
    uint112 public reserve0;
    uint112 public reserve1;

    constructor() ERC20("Uniswap V2 LP", "UNI-V2") {}

    function initialize(address _token0, address _token1) external {
        token0 = _token0;
        token1 = _token1;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setReserves(uint112 r0, uint112 r1) external {
        reserve0 = r0;
        reserve1 = r1;
    }

    function getReserves() external view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, uint32(block.timestamp));
    }
}

contract MockUniswapV2Factory {
    mapping(address => mapping(address => address)) public getPair;

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        if (getPair[tokenA][tokenB] != address(0)) {
            return getPair[tokenA][tokenB];
        }
        MockLPToken lpToken = new MockLPToken();
        // Sort tokens
        (address t0, address t1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        lpToken.initialize(t0, t1);
        pair = address(lpToken);
        getPair[tokenA][tokenB] = pair;
        getPair[tokenB][tokenA] = pair;
    }

    function mintLP(address pair, address to, uint256 amount) external {
        MockLPToken(pair).mint(to, amount);
    }

    function updateReserves(address pair, uint112 r0, uint112 r1) external {
        MockLPToken(pair).setReserves(r0, r1);
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
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
        owner = msg.sender;
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
        liquidity = amountETH;

        require(amountToken >= amountTokenMin, "Insufficient token amount");
        require(amountETH >= amountETHMin, "Insufficient ETH amount");

        // Create pair first (like real Uniswap)
        address pair = MockUniswapV2Factory(factory).createPair(token, WETH);

        // Transfer tokens directly from sender to pair (matches real Uniswap V2 Router behavior)
        IERC20(token).transferFrom(msg.sender, pair, amountToken);

        // Mint LP tokens
        MockUniswapV2Factory(factory).mintLP(pair, to, liquidity);
        // Update reserves
        (address t0,) = token < WETH ? (token, WETH) : (WETH, token);
        if (t0 == token) {
            MockUniswapV2Factory(factory).updateReserves(pair, uint112(amountToken), uint112(amountETH));
        } else {
            MockUniswapV2Factory(factory).updateReserves(pair, uint112(amountETH), uint112(amountToken));
        }

        return (amountToken, amountETH, liquidity);
    }

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts) {
        require(path.length >= 2, "Invalid path");
        amounts = new uint[](path.length);
        amounts[0] = amountIn;

        for (uint i = 0; i < path.length - 1; i++) {
            address pair = MockUniswapV2Factory(factory).getPair(path[i], path[i + 1]);
            if (pair == address(0)) {
                amounts[i + 1] = 0;
                continue;
            }
            MockLPToken lp = MockLPToken(pair);
            (uint112 r0, uint112 r1,) = lp.getReserves();
            address t0 = lp.token0();

            uint reserveIn;
            uint reserveOut;
            if (path[i] == t0) {
                reserveIn = r0;
                reserveOut = r1;
            } else {
                reserveIn = r1;
                reserveOut = r0;
            }

            if (reserveIn == 0 || reserveOut == 0) {
                amounts[i + 1] = 0;
                continue;
            }
            // Uniswap V2 formula: amountOut = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997)
            uint amountInWithFee = amounts[i] * 997;
            amounts[i + 1] = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
        }
    }

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts) {
        require(deadline >= block.timestamp, "Expired");
        require(path[0] == WETH, "Invalid path");

        amounts = this.getAmountsOut(msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "Insufficient output");

        address token = path[path.length - 1];
        address pair = MockUniswapV2Factory(factory).getPair(WETH, token);
        require(pair != address(0), "Pair not found");

        // Transfer tokens from pair to buyer
        IERC20(token).transferFrom(pair, to, amounts[amounts.length - 1]);

        // Update reserves
        MockLPToken lp = MockLPToken(pair);
        (uint112 r0, uint112 r1,) = lp.getReserves();
        address t0 = lp.token0();
        if (t0 == WETH) {
            MockUniswapV2Factory(factory).updateReserves(pair, uint112(uint(r0) + msg.value), uint112(uint(r1) - amounts[1]));
        } else {
            MockUniswapV2Factory(factory).updateReserves(pair, uint112(uint(r0) - amounts[1]), uint112(uint(r1) + msg.value));
        }
    }

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        require(deadline >= block.timestamp, "Expired");
        require(path[path.length - 1] == WETH, "Invalid path");

        amounts = this.getAmountsOut(amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "Insufficient output");

        address token = path[0];
        address pair = MockUniswapV2Factory(factory).getPair(token, WETH);
        require(pair != address(0), "Pair not found");

        // Pull tokens from seller
        IERC20(token).transferFrom(msg.sender, pair, amountIn);

        // Send ETH to seller (from contract balance or mint)
        uint ethOut = amounts[amounts.length - 1];
        payable(to).transfer(ethOut);

        // Update reserves
        MockLPToken lp = MockLPToken(pair);
        (uint112 r0, uint112 r1,) = lp.getReserves();
        address t0 = lp.token0();
        if (t0 == token) {
            MockUniswapV2Factory(factory).updateReserves(pair, uint112(uint(r0) + amountIn), uint112(uint(r1) - ethOut));
        } else {
            MockUniswapV2Factory(factory).updateReserves(pair, uint112(uint(r0) - ethOut), uint112(uint(r1) + amountIn));
        }
    }

    /// @notice Emergency withdraw for stuck ETH/tokens (testnet safety)
    function emergencyWithdrawETH(address to) external onlyOwner {
        require(to != address(0), "Invalid address");
        uint256 bal = address(this).balance;
        if (bal > 0) {
            payable(to).transfer(bal);
        }
    }

    function emergencyWithdrawToken(address token, address to) external onlyOwner {
        require(to != address(0), "Invalid address");
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal > 0) {
            IERC20(token).transfer(to, bal);
        }
    }

    receive() external payable {}
}
