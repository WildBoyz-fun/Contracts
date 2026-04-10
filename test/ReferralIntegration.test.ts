import { expect } from "chai"
import hre from "hardhat";
import { upgrades } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { ethers } from "hardhat";
import { TokenParams } from "./params/TokenParams";

describe("Referral Integration with LaunchPad", function () {
    let params: TokenParams;

    async function deployAll() {
        const [owner, buyer, referrer] = await hre.ethers.getSigners();

        // Deploy core
        const bondingCurve = await hre.ethers.deployContract("BondingCurve");
        const ownerGroupContract = await hre.ethers.deployContract("OwnerGroupContract", [[owner.address]]);
        const launchPadTokenTreasury = await hre.ethers.deployContract("LaunchPanTokenTreasury", [
            await ownerGroupContract.getAddress()
        ]);

        // Deploy ReferralTracker
        const ReferralTrackerFactory = await hre.ethers.getContractFactory("ReferralTracker");
        const referralTracker = await upgrades.deployProxy(ReferralTrackerFactory, [
            await ownerGroupContract.getAddress()
        ], { kind: "uups" });
        await referralTracker.waitForDeployment();

        // Deploy Mock Uniswap
        const factory = await hre.ethers.deployContract("MockUniswapV2Factory");
        const weth = await hre.ethers.deployContract("MockWETH");
        const router = await hre.ethers.deployContract("MockUniswapV2Router", [
            await factory.getAddress(), await weth.getAddress()
        ]);
        const LiquidityProviderFactory = await hre.ethers.getContractFactory("LiquidityProvider");
        const liquidityProvider = await upgrades.deployProxy(LiquidityProviderFactory, [
            await router.getAddress(), await ownerGroupContract.getAddress()
        ], { kind: "uups" });
        await liquidityProvider.waitForDeployment();

        // Deploy ERC404Token implementation + TokenFactory + LaunchPad
        const erc404Impl = await hre.ethers.deployContract("ERC404Token");
        const TokenFactoryFactory = await hre.ethers.getContractFactory("TokenFactory");
        const tokenFactory = await upgrades.deployProxy(TokenFactoryFactory, [
            await ownerGroupContract.getAddress()
        ], { kind: "uups" });
        await tokenFactory.waitForDeployment();
        await tokenFactory.connect(owner).setImplementation(await erc404Impl.getAddress());
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

        // Set ReferralTracker in LaunchPad
        await launchPad.connect(owner).setReferralTrackerContract(await referralTracker.getAddress());

        // Authorize LaunchPad to call ReferralTracker
        await referralTracker.connect(owner).setAuthorizedContract(await launchPad.getAddress(), true);

        params = new TokenParams();
        return { launchPad, referralTracker, ownerGroupContract, params, owner, buyer, referrer };
    }

    async function createToken(launchPad: any, p: TokenParams) {
        const tx = await launchPad.createBioDiversityERC404Token(
            p.tokenTreasuryAddress, p.totalSupply, p.symbol, p.name, p.taxPermil,
            p.imageURI, p.traitType, p.traitValues, p.images, p.description
        );
        const receipt = await tx.wait();
        const event = receipt?.logs
            .map((log: any) => { try { return launchPad.interface.parseLog(log); } catch { return null; } })
            .find((e: any) => e?.name === "ContractDeployed");
        return event?.args.contractAddress;
    }

    it("should record referral points on buy", async function () {
        const { launchPad, referralTracker, buyer, referrer } = await loadFixture(deployAll);

        const contractAddress = await createToken(launchPad, params);

        // Register buyer with referrer
        await referralTracker.connect(buyer).registerWithReferral(referrer.address);

        // Check initial points (account creation: referrer=100, referee=300)
        let referrerPoints = await referralTracker.totalPoints(referrer.address);
        let buyerPoints = await referralTracker.totalPoints(buyer.address);
        expect(referrerPoints).to.equal(100);
        expect(buyerPoints).to.equal(300);

        // Buy tokens
        await launchPad.connect(buyer).buyToken(contractAddress, 0, { value: ethers.parseEther("0.1") });

        // After buy: referrer gets +1, buyer gets +10
        referrerPoints = await referralTracker.totalPoints(referrer.address);
        buyerPoints = await referralTracker.totalPoints(buyer.address);
        expect(referrerPoints).to.equal(101); // 100 + 1
        expect(buyerPoints).to.equal(310);    // 300 + 10
    });

    it("should record referral points on sell", async function () {
        const { launchPad, referralTracker, buyer, referrer } = await loadFixture(deployAll);

        const contractAddress = await createToken(launchPad, params);

        // Register and buy
        await referralTracker.connect(buyer).registerWithReferral(referrer.address);
        await launchPad.connect(buyer).buyToken(contractAddress, 0, { value: ethers.parseEther("0.1") });

        // Approve LaunchPad to pull tokens back
        const erc404 = await hre.ethers.getContractAt("IERC404", contractAddress);
        const balance = await erc404.erc20BalanceOf(buyer.address);
        await erc404.connect(buyer).approve(await launchPad.getAddress(), balance);

        // Sell a small amount (100 tokens)
        const sellAmount = ethers.parseEther("100");
        await launchPad.connect(buyer).sellToken(contractAddress, sellAmount, 0);

        // After sell: referrer gets +0, buyer gets -2
        const referrerPoints = await referralTracker.totalPoints(referrer.address);
        const buyerPoints = await referralTracker.totalPoints(buyer.address);
        expect(referrerPoints).to.equal(101);  // 100 + 1 + 0
        expect(buyerPoints).to.equal(308);     // 300 + 10 - 2
    });

    it("should work without referral tracker set (no revert)", async function () {
        const { launchPad, owner } = await loadFixture(deployAll);

        // Deploy a fresh LaunchPad without referral tracker
        const bondingCurve = await hre.ethers.deployContract("BondingCurve");
        const ownerGroupContract = await hre.ethers.deployContract("OwnerGroupContract", [[owner.address]]);
        const treasury = await hre.ethers.deployContract("LaunchPanTokenTreasury", [await ownerGroupContract.getAddress()]);
        const impl2 = await hre.ethers.deployContract("ERC404Token");
        const TFFactory = await hre.ethers.getContractFactory("TokenFactory");
        const tf = await upgrades.deployProxy(TFFactory, [await ownerGroupContract.getAddress()], { kind: "uups" });
        await tf.waitForDeployment();
        await tf.connect(owner).setImplementation(await impl2.getAddress());
        const LPFactory2 = await hre.ethers.getContractFactory("LaunchPad");
        const launchPadNoRef = await upgrades.deployProxy(LPFactory2, [
            await treasury.getAddress(), await bondingCurve.getAddress(), await ownerGroupContract.getAddress()
        ], { kind: "uups" });
        await launchPadNoRef.waitForDeployment();
        await launchPadNoRef.connect(owner).setTokenFactory(await tf.getAddress());
        await tf.connect(owner).setLaunchPad(await launchPadNoRef.getAddress());

        const contractAddress = await createToken(launchPadNoRef, params);

        // Buy should work without reverting even though referral tracker is not set
        await expect(
            launchPadNoRef.connect(owner).buyToken(contractAddress, 0, { value: ethers.parseEther("0.1") })
        ).to.not.be.reverted;
    });

    it("should work when user has no referrer", async function () {
        const { launchPad, referralTracker, buyer } = await loadFixture(deployAll);

        const contractAddress = await createToken(launchPad, params);

        // Buy without registering referral - should not revert
        await expect(
            launchPad.connect(buyer).buyToken(contractAddress, 0, { value: ethers.parseEther("0.1") })
        ).to.not.be.reverted;

        // Buyer still gets referee reward (10 points for buy, even without referrer)
        const buyerPoints = await referralTracker.totalPoints(buyer.address);
        expect(buyerPoints).to.equal(10);
    });
});
