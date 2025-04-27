import { expect } from "chai"
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"

describe("LiquidityProvider", function () {
    const uniswapV2FactoryAddress = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"
    const uniswapV2RouterAddress = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"

    async function deployLiquidityProvider() {
        const factory = await hre.ethers.getContractAt("UniswapV2Factory", uniswapV2FactoryAddress)

        const router = await hre.ethers.getContractAt("UniswapV2Router02", uniswapV2RouterAddress)

        const liquidityProvider = await hre.ethers.deployContract("LiquidityProvider", [await router.getAddress()]);

        const token = await hre.ethers.deployContract("MockERC20", ["MockToken", "MTK"]);

        return { factory, router, liquidityProvider, token };
    }

    it("Should be provided liquidity", async function () {
        const [owner] = await hre.ethers.getSigners();

        const { factory, router, liquidityProvider, token } = await loadFixture(deployLiquidityProvider);

        const tokenAmount = hre.ethers.parseEther("1000")
        const ethAmount = hre.ethers.parseEther("10")

        await token.mint(liquidityProvider.getAddress(), tokenAmount)

        await owner.sendTransaction({
            to: liquidityProvider.getAddress(),
            value: ethAmount,
        })

        const lpTx = await liquidityProvider.connect(owner).addLiquidityETH(
            token.getAddress(),
            tokenAmount,
            ethAmount,
        )
        await lpTx.wait()

        const pairAddress = await factory.getPair(token.getAddress(), router.WETH())

        expect(pairAddress).to.not.equal(hre.ethers.ZeroAddress)

        const swapTx = await router.swapExactETHForTokens(
            0,
            [router.WETH(), token.getAddress()],
            owner.address,
            Math.floor(Date.now() / 1000) + 60,
            {value: hre.ethers.parseEther("1")}
        )
        await swapTx.wait()

        const balance = await token.balanceOf(owner.address)
        console.log(`token balance: ${hre.ethers.formatEther(balance)}`)

        expect(balance).greaterThan(hre.ethers.parseEther("0"))
    })
});
