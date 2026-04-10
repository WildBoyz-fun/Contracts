import { expect } from "chai"
import hre from "hardhat";
import { upgrades } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { ethers } from "hardhat";
import { TokenParams } from "./params/TokenParams";

describe("LaunchPad Auto LP & Graduation", function () {
    let params: TokenParams;

    async function initParams() {
        const [owner, buyer] = await hre.ethers.getSigners();

        // Deploy Mock Uniswap
        const factory = await hre.ethers.deployContract("MockUniswapV2Factory");
        const weth = await hre.ethers.deployContract("MockWETH");
        const router = await hre.ethers.deployContract("MockUniswapV2Router", [
            await factory.getAddress(),
            await weth.getAddress()
        ]);

        // Deploy core contracts
        const bondingCurve = await hre.ethers.deployContract("BondingCurve");
        const ownerGroupContract = await hre.ethers.deployContract("OwnerGroupContract", [[owner.address]]);
        const launchPadTokenTreasury = await hre.ethers.deployContract("LaunchPanTokenTreasury", [
            await ownerGroupContract.getAddress()
        ]);

        // Deploy LiquidityProvider with proxy
        const LiquidityProviderFactory = await hre.ethers.getContractFactory("LiquidityProvider");
        const liquidityProvider = await upgrades.deployProxy(LiquidityProviderFactory, [
            await router.getAddress(),
            await ownerGroupContract.getAddress()
        ], { kind: "uups" });
        await liquidityProvider.waitForDeployment();

        // Deploy ERC404Token implementation + TokenFactory
        const erc404Impl = await hre.ethers.deployContract("ERC404Token");
        const TokenFactoryFactory = await hre.ethers.getContractFactory("TokenFactory");
        const tokenFactory = await upgrades.deployProxy(TokenFactoryFactory, [
            await ownerGroupContract.getAddress()
        ], { kind: "uups" });
        await tokenFactory.waitForDeployment();
        await tokenFactory.connect(owner).setImplementation(await erc404Impl.getAddress());

        // Deploy LaunchPad
        const LaunchPadFactory = await hre.ethers.getContractFactory("LaunchPad");
        const launchPad = await upgrades.deployProxy(LaunchPadFactory, [
            await launchPadTokenTreasury.getAddress(),
            await bondingCurve.getAddress(),
            await ownerGroupContract.getAddress()
        ], { kind: "uups" });
        await launchPad.waitForDeployment();

        // Wire up
        await launchPad.connect(owner).setLiquidityProviderContract(await liquidityProvider.getAddress());
        await liquidityProvider.connect(owner).setLaunchPad(await launchPad.getAddress());
        await launchPad.connect(owner).setTokenFactory(await tokenFactory.getAddress());
        await tokenFactory.connect(owner).setLaunchPad(await launchPad.getAddress());

        params = new TokenParams();
        return { launchPad, liquidityProvider, router, factory, weth, ownerGroupContract, bondingCurve, params, owner, buyer };
    }

    async function createToken(launchPad: any, p: TokenParams) {
        const tx = await launchPad.createBioDiversityERC404Token(
            p.tokenTreasuryAddress,
            p.totalSupply,
            p.symbol,
            p.name,
            p.taxPermil,
            p.imageURI,
            p.traitType,
            p.traitValues,
            p.images,
            p.description
        );
        const receipt = await tx.wait();
        const deployEvent = receipt?.logs
            .map((log: any) => { try { return launchPad.interface.parseLog(log); } catch { return null; } })
            .find((e: any) => e?.name === "ContractDeployed");
        return deployEvent?.args.contractAddress;
    }

    // Buy in small increments to stay within gas limits (ERC721 minting is expensive)
    async function buyUntilGraduation(launchPad: any, buyer: any, contractAddress: string) {
        // Use 0.5 ETH per buy to keep NFT minting manageable
        const chunkSize = ethers.parseEther("0.5");
        for (let i = 0; i < 200; i++) {
            const info = await launchPad.contractInfo(contractAddress);
            if (!info.saleIsActive) return;
            await launchPad.connect(buyer).buyToken(contractAddress, 0, { value: chunkSize });
        }
    }

    it("should support emergency graduation by owner", async function () {
        const { launchPad, liquidityProvider, params, owner, buyer } = await loadFixture(initParams);

        const contractAddress = await createToken(launchPad, params);

        // Buy a small amount
        await launchPad.connect(buyer).buyToken(contractAddress, 0, { value: ethers.parseEther("0.1") });

        // Not graduated yet
        let info = await launchPad.contractInfo(contractAddress);
        expect(info.saleIsActive).to.be.true;
        expect(info.isGraduated).to.be.false;

        // Non-owner cannot emergency graduate
        await expect(
            launchPad.connect(buyer).emergencyGraduate(contractAddress)
        ).to.be.revertedWith("Only Owner have a permission.");

        // Owner can emergency graduate
        await launchPad.connect(owner).emergencyGraduate(contractAddress);

        // Verify state
        info = await launchPad.contractInfo(contractAddress);
        expect(info.saleIsActive).to.be.false;
        expect(info.isGraduated).to.be.true;

        // Verify pair created & tracked
        const pairAddress = await launchPad.getGraduatedPair(contractAddress);
        expect(pairAddress).to.not.equal(hre.ethers.ZeroAddress);

        // Verify LP tokens burned
        const DEAD = "0x000000000000000000000000000000000000dEaD";
        const lpToken = await hre.ethers.getContractAt("IERC20", pairAddress);
        const deadBalance = await lpToken.balanceOf(DEAD);
        expect(deadBalance).to.be.greaterThan(0);

        // Verify LiquidityProvider tracking
        expect(await liquidityProvider.isGraduated(contractAddress)).to.be.true;
        const gradInfo = await liquidityProvider.getGraduationInfo(contractAddress);
        expect(gradInfo.pairAddress).to.equal(pairAddress);
        expect(gradInfo.lpTokensBurned).to.be.greaterThan(0);

        // Cannot buy after graduation
        await expect(
            launchPad.connect(buyer).buyToken(contractAddress, 0, { value: ethers.parseEther("0.1") })
        ).to.be.revertedWith("SNA");
    });

    it("should track multiple graduated tokens", async function () {
        const { launchPad, liquidityProvider, params, owner, buyer } = await loadFixture(initParams);

        const addr1 = await createToken(launchPad, params);
        await launchPad.connect(buyer).buyToken(addr1, 0, { value: ethers.parseEther("0.1") });
        await launchPad.connect(owner).emergencyGraduate(addr1);

        const addr2 = await createToken(launchPad, params);
        await launchPad.connect(buyer).buyToken(addr2, 0, { value: ethers.parseEther("0.1") });
        await launchPad.connect(owner).emergencyGraduate(addr2);

        expect(await liquidityProvider.isGraduated(addr1)).to.be.true;
        expect(await liquidityProvider.isGraduated(addr2)).to.be.true;
        expect(await liquidityProvider.getGraduatedTokenCount()).to.equal(2);

        // Different pairs for different tokens
        const pair1 = await launchPad.getGraduatedPair(addr1);
        const pair2 = await launchPad.getGraduatedPair(addr2);
        expect(pair1).to.not.equal(pair2);
    });

    it("should report graduation status correctly", async function () {
        const { launchPad, params, owner, buyer } = await loadFixture(initParams);

        const contractAddress = await createToken(launchPad, params);
        expect(await launchPad.getContractGraduationStatus(contractAddress)).to.be.false;

        await launchPad.connect(buyer).buyToken(contractAddress, 0, { value: ethers.parseEther("0.1") });
        await launchPad.connect(owner).emergencyGraduate(contractAddress);

        expect(await launchPad.getContractGraduationStatus(contractAddress)).to.be.true;
    });

    it("should auto-graduate when target is reached", async function () {
        this.timeout(300000);
        const { launchPad, liquidityProvider, params, buyer } = await loadFixture(initParams);

        const contractAddress = await createToken(launchPad, params);

        // Buy in small chunks until graduation triggers automatically
        await buyUntilGraduation(launchPad, buyer, contractAddress);

        // Verify auto-graduation happened
        const info = await launchPad.contractInfo(contractAddress);
        expect(info.saleIsActive).to.be.false;
        expect(info.isGraduated).to.be.true;
        expect(info.ethDepositBalance).to.equal(0);

        // Pair was created
        const pairAddress = await launchPad.getGraduatedPair(contractAddress);
        expect(pairAddress).to.not.equal(hre.ethers.ZeroAddress);

        // LP tokens burned
        expect(await liquidityProvider.isGraduated(contractAddress)).to.be.true;
    });
});
