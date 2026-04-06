// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOwnerGroupContract} from "./libs/IOwnerGroupContract.sol";

contract LiquidityProvider {
    IUniswapV2Router02 public immutable router;
    address public immutable WETH;
    address public immutable factory;
    IOwnerGroupContract private _ownerGroupContract;
    address public launchPad;

    // Dead address for permanent LP lock
    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    // Slippage tolerance: 95 means accept 95% of expected amounts minimum
    uint256 public slippageTolerance = 99;

    struct GraduationInfo {
        address tokenAddress;
        address pairAddress;
        uint256 tokenAmount;
        uint256 ethAmount;
        uint256 lpTokensBurned;
        uint256 timestamp;
    }

    // token -> pair address
    mapping(address => address) public tokenPairs;
    // token -> graduation info
    mapping(address => GraduationInfo) public graduationInfo;
    // token -> burned LP amount
    mapping(address => uint256) public burnedLPTokens;
    // all graduated tokens
    address[] public graduatedTokens;

    event LiquidityAdded(
        address indexed token,
        address indexed pair,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 liquidity
    );
    event LPTokensBurned(
        address indexed token,
        address indexed pair,
        uint256 amount
    );
    event SlippageToleranceUpdated(uint256 oldTolerance, uint256 newTolerance);

    modifier onlyOwnerGroup() {
        require(_ownerGroupContract.isOwner(msg.sender), "Only Owner");
        _;
    }

    modifier onlyLaunchPadOrOwner() {
        require(
            msg.sender == launchPad || _ownerGroupContract.isOwner(msg.sender),
            "Only LaunchPad or Owner"
        );
        _;
    }

    constructor(address _router, address ownerGroupContract) {
        require(_router != address(0), "Invalid router");
        require(ownerGroupContract != address(0), "Invalid owner group");
        router = IUniswapV2Router02(_router);
        _ownerGroupContract = IOwnerGroupContract(ownerGroupContract);
        factory = router.factory();
        WETH = router.WETH();
    }

    function setLaunchPad(address _launchPad) external onlyOwnerGroup {
        require(_launchPad != address(0), "Invalid address");
        launchPad = _launchPad;
    }

    function setSlippageTolerance(uint256 _tolerance) external onlyOwnerGroup {
        require(_tolerance >= 80 && _tolerance <= 100, "Tolerance 80-100");
        emit SlippageToleranceUpdated(slippageTolerance, _tolerance);
        slippageTolerance = _tolerance;
    }

    /// @notice Add liquidity to Uniswap V2 and burn LP tokens to permanently lock liquidity
    function addLiquidityETH(
        address token,
        uint256 tokenAmount,
        uint256 ethAmount
    ) external payable onlyLaunchPadOrOwner returns (address pair, uint256 liquidity) {
        require(tokenAmount > 0 && ethAmount > 0, "Zero amount");

        // Approve router
        IERC20(token).approve(address(router), tokenAmount);

        // Slippage protection
        uint256 amountTokenMin = (tokenAmount * slippageTolerance) / 100;
        uint256 amountETHMin = (ethAmount * slippageTolerance) / 100;

        uint256 amountToken;
        uint256 amountETH;
        (amountToken, amountETH, liquidity) = router.addLiquidityETH{value: ethAmount}(
            token,
            tokenAmount,
            amountTokenMin,
            amountETHMin,
            address(this),
            block.timestamp + 600
        );

        require(liquidity > 0, "Liquidity provision failed");

        // Get pair address
        pair = IUniswapV2Factory(factory).getPair(token, WETH);
        require(pair != address(0), "Pair not created");

        // Burn LP tokens → permanent liquidity lock
        uint256 lpBalance = IERC20(pair).balanceOf(address(this));
        if (lpBalance > 0) {
            IERC20(pair).transfer(DEAD_ADDRESS, lpBalance);
            burnedLPTokens[token] = lpBalance;
            emit LPTokensBurned(token, pair, lpBalance);
        }

        // Record graduation
        tokenPairs[token] = pair;
        graduatedTokens.push(token);
        graduationInfo[token] = GraduationInfo({
            tokenAddress: token,
            pairAddress: pair,
            tokenAmount: amountToken,
            ethAmount: amountETH,
            lpTokensBurned: lpBalance,
            timestamp: block.timestamp
        });

        emit LiquidityAdded(token, pair, amountToken, amountETH, liquidity);

        // Refund leftovers to caller (LaunchPad)
        uint256 remainingTokens = IERC20(token).balanceOf(address(this));
        if (remainingTokens > 0) {
            IERC20(token).transfer(msg.sender, remainingTokens);
        }
        if (address(this).balance > 0) {
            payable(msg.sender).transfer(address(this).balance);
        }
    }

    // --- View Functions ---

    function getPairAddress(address token) external view returns (address) {
        return tokenPairs[token];
    }

    function isGraduated(address token) external view returns (bool) {
        return tokenPairs[token] != address(0);
    }

    function getGraduatedTokenCount() external view returns (uint256) {
        return graduatedTokens.length;
    }

    function getGraduatedTokens() external view returns (address[] memory) {
        return graduatedTokens;
    }

    function getGraduationInfo(address token) external view returns (GraduationInfo memory) {
        return graduationInfo[token];
    }

    receive() external payable {}
}
