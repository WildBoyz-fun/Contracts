// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IOwnerGroupContract} from "./libs/IOwnerGroupContract.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract LiquidityProvider is Initializable, UUPSUpgradeable {
    IUniswapV2Router02 public router;
    address public WETH;
    address public factory;
    IOwnerGroupContract private _ownerGroupContract;
    address public launchPad;

    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    uint256 public slippageTolerance;

    struct GraduationInfo {
        address tokenAddress;
        address pairAddress;
        uint256 tokenAmount;
        uint256 ethAmount;
        uint256 lpTokensBurned;
        uint256 timestamp;
    }

    mapping(address => address) public tokenPairs;
    mapping(address => GraduationInfo) public graduationInfo;
    mapping(address => uint256) public burnedLPTokens;
    address[] public graduatedTokens;

    event LiquidityAdded(address indexed token, address indexed pair, uint256 tokenAmount, uint256 ethAmount, uint256 liquidity);
    event LPTokensBurned(address indexed token, address indexed pair, uint256 amount);
    event SlippageToleranceUpdated(uint256 oldTolerance, uint256 newTolerance);

    modifier onlyOwnerGroup() {
        require(_ownerGroupContract.isOwner(msg.sender), "Only Owner");
        _;
    }

    modifier onlyLaunchPadOrOwner() {
        require(msg.sender == launchPad || _ownerGroupContract.isOwner(msg.sender), "Only LaunchPad or Owner");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _router, address ownerGroupContract) external initializer {
        require(_router != address(0), "Invalid router");
        require(ownerGroupContract != address(0), "Invalid owner group");

        router = IUniswapV2Router02(_router);
        _ownerGroupContract = IOwnerGroupContract(ownerGroupContract);
        factory = router.factory();
        WETH = router.WETH();
        slippageTolerance = 99;
    }

    function _authorizeUpgrade(address) internal override onlyOwnerGroup {}

    function setLaunchPad(address _launchPad) external onlyOwnerGroup {
        require(_launchPad != address(0), "Invalid address");
        launchPad = _launchPad;
    }

    function setSlippageTolerance(uint256 _tolerance) external onlyOwnerGroup {
        require(_tolerance >= 80 && _tolerance <= 100, "Tolerance 80-100");
        emit SlippageToleranceUpdated(slippageTolerance, _tolerance);
        slippageTolerance = _tolerance;
    }

    function addLiquidityETH(
        address token, uint256 tokenAmount, uint256 ethAmount
    ) external payable onlyLaunchPadOrOwner returns (address pair, uint256 liquidity) {
        require(tokenAmount > 0 && ethAmount > 0, "Zero amount");

        IERC20(token).approve(address(router), tokenAmount);

        uint256 amountTokenMin = (tokenAmount * slippageTolerance) / 100;
        uint256 amountETHMin = (ethAmount * slippageTolerance) / 100;

        uint256 amountToken;
        uint256 amountETH;
        (amountToken, amountETH, liquidity) = router.addLiquidityETH{value: ethAmount}(
            token, tokenAmount, amountTokenMin, amountETHMin, address(this), block.timestamp + 600
        );

        require(liquidity > 0, "Liquidity provision failed");

        pair = IUniswapV2Factory(factory).getPair(token, WETH);
        require(pair != address(0), "Pair not created");

        uint256 lpBalance = IERC20(pair).balanceOf(address(this));
        if (lpBalance > 0) {
            IERC20(pair).transfer(DEAD_ADDRESS, lpBalance);
            burnedLPTokens[token] = lpBalance;
            emit LPTokensBurned(token, pair, lpBalance);
        }

        tokenPairs[token] = pair;
        graduatedTokens.push(token);
        graduationInfo[token] = GraduationInfo({
            tokenAddress: token, pairAddress: pair,
            tokenAmount: amountToken, ethAmount: amountETH,
            lpTokensBurned: lpBalance, timestamp: block.timestamp
        });

        emit LiquidityAdded(token, pair, amountToken, amountETH, liquidity);

        uint256 remainingTokens = IERC20(token).balanceOf(address(this));
        if (remainingTokens > 0) IERC20(token).transfer(msg.sender, remainingTokens);
        if (address(this).balance > 0) payable(msg.sender).transfer(address(this).balance);
    }

    function getPairAddress(address token) external view returns (address) { return tokenPairs[token]; }
    function isGraduated(address token) external view returns (bool) { return tokenPairs[token] != address(0); }
    function getGraduatedTokenCount() external view returns (uint256) { return graduatedTokens.length; }
    function getGraduatedTokens() external view returns (address[] memory) { return graduatedTokens; }
    function getGraduationInfo(address token) external view returns (GraduationInfo memory) { return graduationInfo[token]; }

    receive() external payable {}

    uint256[50] private __gap;
}
