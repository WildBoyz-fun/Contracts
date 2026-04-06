import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with:", deployer.address);
  console.log("Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");

  // 1. Uniswap V2
  console.log("\n--- Deploying Uniswap V2 ---");
  const weth = await (await ethers.deployContract("MockWETH")).waitForDeployment();
  console.log("MockWETH:", await weth.getAddress());

  const factory = await (await ethers.deployContract("MockUniswapV2Factory")).waitForDeployment();
  console.log("MockFactory:", await factory.getAddress());

  const router = await (await ethers.deployContract("MockUniswapV2Router", [await factory.getAddress(), await weth.getAddress()])).waitForDeployment();
  console.log("MockRouter:", await router.getAddress());

  // 2. Core
  console.log("\n--- Deploying Core ---");
  const bondingCurve = await (await ethers.deployContract("BondingCurve")).waitForDeployment();
  console.log("BondingCurve:", await bondingCurve.getAddress());

  const ownerGroup = await (await ethers.deployContract("OwnerGroupContract", [[deployer.address]])).waitForDeployment();
  console.log("OwnerGroup:", await ownerGroup.getAddress());

  const tokenTreasury = await (await ethers.deployContract("TokenTreasury", [await ownerGroup.getAddress()])).waitForDeployment();
  console.log("TokenTreasury:", await tokenTreasury.getAddress());

  // 3. TokenFactory
  const tokenFactory = await (await ethers.deployContract("TokenFactory", [await ownerGroup.getAddress()])).waitForDeployment();
  console.log("TokenFactory:", await tokenFactory.getAddress());

  // 4. LiquidityProvider
  const liquidityProvider = await (await ethers.deployContract("LiquidityProvider", [await router.getAddress(), await ownerGroup.getAddress()])).waitForDeployment();
  console.log("LiquidityProvider:", await liquidityProvider.getAddress());

  // 5. ReferralTracker
  const referralTracker = await (await ethers.deployContract("ReferralTracker", [await ownerGroup.getAddress()])).waitForDeployment();
  console.log("ReferralTracker:", await referralTracker.getAddress());

  // 6. LaunchPad
  const launchPad = await (await ethers.deployContract("LaunchPad", [
    await tokenTreasury.getAddress(),
    await bondingCurve.getAddress(),
    await ownerGroup.getAddress(),
  ])).waitForDeployment();
  console.log("LaunchPad:", await launchPad.getAddress());

  // 7. Wire up
  console.log("\n--- Wiring contracts ---");
  await (await launchPad.setLiquidityProviderContract(await liquidityProvider.getAddress())).wait();
  console.log("  LaunchPad -> LiquidityProvider ✓");

  await (await launchPad.setTokenFactory(await tokenFactory.getAddress())).wait();
  console.log("  LaunchPad -> TokenFactory ✓");

  await (await launchPad.setReferralTrackerContract(await referralTracker.getAddress())).wait();
  console.log("  LaunchPad -> ReferralTracker ✓");

  await (await liquidityProvider.setLaunchPad(await launchPad.getAddress())).wait();
  console.log("  LiquidityProvider -> LaunchPad ✓");

  await (await tokenFactory.setLaunchPad(await launchPad.getAddress())).wait();
  console.log("  TokenFactory -> LaunchPad ✓");

  await (await referralTracker.setAuthorizedContract(await launchPad.getAddress(), true)).wait();
  console.log("  ReferralTracker authorized LaunchPad ✓");

  // 8. Set low graduation target for testnet
  await (await launchPad.setTargetFundRaisingAmount(ethers.parseEther("1000"))).wait();
  console.log("  Graduation target: 1000 tokens ✓");

  // Summary
  console.log("\n========== DEPLOYMENT COMPLETE ==========");
  console.log(`WETH:              ${await weth.getAddress()}`);
  console.log(`UniswapFactory:    ${await factory.getAddress()}`);
  console.log(`UniswapRouter:     ${await router.getAddress()}`);
  console.log(`BondingCurve:      ${await bondingCurve.getAddress()}`);
  console.log(`OwnerGroup:        ${await ownerGroup.getAddress()}`);
  console.log(`TokenTreasury:     ${await tokenTreasury.getAddress()}`);
  console.log(`TokenFactory:      ${await tokenFactory.getAddress()}`);
  console.log(`LiquidityProvider: ${await liquidityProvider.getAddress()}`);
  console.log(`ReferralTracker:   ${await referralTracker.getAddress()}`);
  console.log(`LaunchPad:         ${await launchPad.getAddress()}`);
  console.log(`\nOwner:           ${deployer.address}`);
  console.log(`Remaining balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH`);
  console.log("==========================================");
}

main().catch(console.error);
