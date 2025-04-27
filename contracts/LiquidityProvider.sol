// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LiquidityProvider {
    address private router;

    constructor(address _router) {
        router = _router;
    }

    function addLiquidityETH(
        address token,
        uint256 tokenAmount,
        uint256 ethAmount
    ) external {
        IERC20(token).approve(router, tokenAmount);

        (, , uint256 liquidity) = IUniswapV2Router02(router).addLiquidityETH{ value: ethAmount }(
            token,
            tokenAmount,
            0,
            0,
            address(this),
            block.timestamp + 600
        );

        require (liquidity > 0, "Liquidity provision failed");
    }

    receive() external payable {}
}
