import { expect } from "chai"
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"

describe("LiquidityProvider", function () {

    async function deployLiquidityProvider() {
        const [owner, other] = await hre.ethers.getSigners();

        const factory = await hre.ethers.deployContract("MockUniswapV2Factory");
        const weth = await hre.ethers.deployContract("MockWETH");
        const router = await hre.ethers.deployContract("MockUniswapV2Router", [
            await factory.getAddress(),
            await weth.getAddress()
        ]);
        const ownerGroupContract = await hre.ethers.deployContract("OwnerGroupContract", [[owner.address]]);

        const liquidityProvider = await hre.ethers.deployContract("LiquidityProvider", [
            await router.getAddress(),
            await ownerGroupContract.getAddress()
        ]);

        // Set owner as launchPad for direct testing
        await liquidityProvider.connect(owner).setLaunchPad(owner.address);

        const token = await hre.ethers.deployContract("MockERC20", ["MockToken", "MTK"]);

        return { factory, router, weth, liquidityProvider, token, ownerGroupContract, owner, other };
    }

    it("Should add liquidity, burn LP tokens, and track graduation", async function () {
        const { factory, weth, liquidityProvider, token, owner } = await loadFixture(deployLiquidityProvider);

        const tokenAmount = hre.ethers.parseEther("1000");
        const ethAmount = hre.ethers.parseEther("10");

        // Send tokens to LP contract
        await token.mint(await liquidityProvider.getAddress(), tokenAmount);

        // Add liquidity
        const tx = await liquidityProvider.connect(owner).addLiquidityETH(
            await token.getAddress(),
            tokenAmount,
            ethAmount,
            { value: ethAmount }
        );
        await tx.wait();

        // Pair was created
        const pairAddress = await factory.getPair(await token.getAddress(), await weth.getAddress());
        expect(pairAddress).to.not.equal(hre.ethers.ZeroAddress);

        // LP tokens burned
        const DEAD = "0x000000000000000000000000000000000000dEaD";
        const lpToken = await hre.ethers.getContractAt("IERC20", pairAddress);
        const deadBalance = await lpToken.balanceOf(DEAD);
        expect(deadBalance).to.be.greaterThan(0);

        // Graduation tracked
        expect(await liquidityProvider.isGraduated(await token.getAddress())).to.be.true;
        const gradInfo = await liquidityProvider.getGraduationInfo(await token.getAddress());
        expect(gradInfo.pairAddress).to.equal(pairAddress);
        expect(gradInfo.lpTokensBurned).to.be.greaterThan(0);
    });

    it("Should reject non-authorized callers", async function () {
        const { liquidityProvider, token, other } = await loadFixture(deployLiquidityProvider);

        await expect(
            liquidityProvider.connect(other).addLiquidityETH(
                await token.getAddress(),
                hre.ethers.parseEther("1000"),
                hre.ethers.parseEther("10"),
                { value: hre.ethers.parseEther("10") }
            )
        ).to.be.revertedWith("Only LaunchPad or Owner");
    });

    it("Should allow slippage tolerance update by owner only", async function () {
        const { liquidityProvider, owner, other } = await loadFixture(deployLiquidityProvider);

        await liquidityProvider.connect(owner).setSlippageTolerance(90);
        expect(await liquidityProvider.slippageTolerance()).to.equal(90);

        await expect(
            liquidityProvider.connect(other).setSlippageTolerance(90)
        ).to.be.revertedWith("Only Owner");

        await expect(
            liquidityProvider.connect(owner).setSlippageTolerance(79)
        ).to.be.revertedWith("Tolerance 80-100");
    });
});
