import { ethers, upgrades } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with:", deployer.address);
  console.log("Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");

  // 1. Uniswap V2 (non-upgradeable)
  console.log("\n--- Deploying Uniswap V2 ---");
  const weth = await (await ethers.deployContract("MockWETH")).waitForDeployment();
  console.log("MockWETH:", await weth.getAddress());

  const factory = await (await ethers.deployContract("MockUniswapV2Factory")).waitForDeployment();
  console.log("MockFactory:", await factory.getAddress());

  const router = await (await ethers.deployContract("MockUniswapV2Router", [await factory.getAddress(), await weth.getAddress()])).waitForDeployment();
  console.log("MockRouter:", await router.getAddress());

  // 2. Core (non-upgradeable)
  console.log("\n--- Deploying Core ---");
  const bondingCurve = await (await ethers.deployContract("BondingCurve")).waitForDeployment();
  console.log("BondingCurve:", await bondingCurve.getAddress());

  const ownerGroup = await (await ethers.deployContract("OwnerGroupContract", [[deployer.address]])).waitForDeployment();
  console.log("OwnerGroup:", await ownerGroup.getAddress());

  const tokenTreasury = await (await ethers.deployContract("TokenTreasury", [await ownerGroup.getAddress()])).waitForDeployment();
  console.log("TokenTreasury:", await tokenTreasury.getAddress());

  // 3. ERC404Token implementation (for clone pattern, non-upgradeable)
  const erc404Impl = await (await ethers.deployContract("ERC404Token")).waitForDeployment();
  console.log("ERC404Token (impl):", await erc404Impl.getAddress());

  // 4. Upgradeable contracts via UUPS proxy
  console.log("\n--- Deploying Upgradeable Proxies ---");

  const TokenFactory = await ethers.getContractFactory("TokenFactory");
  const tokenFactory = await upgrades.deployProxy(TokenFactory, [await ownerGroup.getAddress()], { kind: "uups" });
  await tokenFactory.waitForDeployment();
  console.log("TokenFactory (proxy):", await tokenFactory.getAddress());

  const LiquidityProvider = await ethers.getContractFactory("LiquidityProvider");
  const liquidityProvider = await upgrades.deployProxy(LiquidityProvider, [await router.getAddress(), await ownerGroup.getAddress()], { kind: "uups" });
  await liquidityProvider.waitForDeployment();
  console.log("LiquidityProvider (proxy):", await liquidityProvider.getAddress());

  const ReferralTracker = await ethers.getContractFactory("ReferralTracker");
  const referralTracker = await upgrades.deployProxy(ReferralTracker, [await ownerGroup.getAddress()], { kind: "uups" });
  await referralTracker.waitForDeployment();
  console.log("ReferralTracker (proxy):", await referralTracker.getAddress());

  const LaunchPad = await ethers.getContractFactory("LaunchPad");
  const launchPad = await upgrades.deployProxy(LaunchPad, [
    await tokenTreasury.getAddress(),
    await bondingCurve.getAddress(),
    await ownerGroup.getAddress(),
  ], { kind: "uups" });
  await launchPad.waitForDeployment();
  console.log("LaunchPad (proxy):", await launchPad.getAddress());

  // 5. Wire up
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

  await (await tokenFactory.setImplementation(await erc404Impl.getAddress())).wait();
  console.log("  TokenFactory -> ERC404Token implementation ✓");

  await (await referralTracker.setAuthorizedContract(await launchPad.getAddress(), true)).wait();
  console.log("  ReferralTracker authorized LaunchPad ✓");

  // 6. Set low graduation target for testnet
  await (await launchPad.setTargetFundRaisingAmount(ethers.parseEther("1000"))).wait();
  console.log("  Graduation target: 1000 tokens ✓");

  // Summary
  console.log("\n========== DEPLOYMENT COMPLETE (UUPS Proxies) ==========");
  console.log(`WETH:              ${await weth.getAddress()}`);
  console.log(`UniswapFactory:    ${await factory.getAddress()}`);
  console.log(`UniswapRouter:     ${await router.getAddress()}`);
  console.log(`BondingCurve:      ${await bondingCurve.getAddress()}`);
  console.log(`OwnerGroup:        ${await ownerGroup.getAddress()}`);
  console.log(`TokenTreasury:     ${await tokenTreasury.getAddress()}`);
  console.log(`ERC404Impl:        ${await erc404Impl.getAddress()}`);
  console.log(`TokenFactory:      ${await tokenFactory.getAddress()} (UUPS proxy)`);
  console.log(`LiquidityProvider: ${await liquidityProvider.getAddress()} (UUPS proxy)`);
  console.log(`ReferralTracker:   ${await referralTracker.getAddress()} (UUPS proxy)`);
  console.log(`LaunchPad:         ${await launchPad.getAddress()} (UUPS proxy)`);
  console.log(`\nOwner:           ${deployer.address}`);
  console.log(`Remaining balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH`);
  console.log("=========================================================");
}

main().catch(console.error);
