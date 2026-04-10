import { ethers, upgrades } from "hardhat";

/**
 * Upgrade script:
 * 1. Deploy new Mock Uniswap (WETH, Factory, Router)
 * 2. Upgrade LaunchPad (UUPS) — new _graduateToken with exempt settings
 * 3. Update LiquidityProvider router to new Mock Router
 */

// Existing deployed proxy addresses (Base Sepolia)
const LAUNCHPAD_PROXY = "0x4844874dDeC2C0b5040130515b8aA91861483aA8";
const LIQUIDITY_PROVIDER_PROXY = "0x953cb16A86c775D0F9662316F066B6271C5A4f14";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);
  console.log("Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");

  // 1. Deploy new Mock Uniswap contracts
  console.log("\n--- Deploying New Mock Uniswap ---");
  const weth = await (await ethers.deployContract("MockWETH")).waitForDeployment();
  console.log("MockWETH:", await weth.getAddress());

  const factory = await (await ethers.deployContract("MockUniswapV2Factory")).waitForDeployment();
  console.log("MockFactory:", await factory.getAddress());

  const router = await (await ethers.deployContract("MockUniswapV2Router", [
    await factory.getAddress(), await weth.getAddress()
  ])).waitForDeployment();
  console.log("MockRouter:", await router.getAddress());

  // 2. Upgrade LaunchPad via UUPS
  console.log("\n--- Upgrading LaunchPad ---");
  const LaunchPad = await ethers.getContractFactory("LaunchPad");
  const launchPad = await upgrades.upgradeProxy(LAUNCHPAD_PROXY, LaunchPad);
  await launchPad.waitForDeployment();
  console.log("LaunchPad upgraded at:", LAUNCHPAD_PROXY);

  // 3. Update LiquidityProvider — deploy new implementation and point to new router
  // LiquidityProvider's router is set during initialize(), so we need to upgrade and re-init
  // Actually, we just need to add a setRouter function or redeploy.
  // Since LiquidityProvider doesn't have setRouter, we upgrade it with one.
  // For now, let's check if we can just upgrade and keep the existing state.

  // Actually the simplest approach: the router address is stored in LiquidityProvider's storage.
  // We need to either:
  // a) Add a setRouter function to LiquidityProvider and upgrade
  // b) Or use a reinitializer
  // Let's add setRouter to LiquidityProvider and upgrade.

  console.log("\n--- Upgrading LiquidityProvider ---");
  const LiquidityProvider = await ethers.getContractFactory("LiquidityProvider");
  const liquidityProvider = await upgrades.upgradeProxy(LIQUIDITY_PROVIDER_PROXY, LiquidityProvider);
  await liquidityProvider.waitForDeployment();
  console.log("LiquidityProvider upgraded at:", LIQUIDITY_PROVIDER_PROXY);

  // Set new router
  const newRouterAddr = await router.getAddress();
  await (await liquidityProvider.setRouter(newRouterAddr)).wait();
  console.log("LiquidityProvider router updated to:", newRouterAddr);

  // Verify
  console.log("\n--- Verification ---");
  console.log("LP router:", await liquidityProvider.router());
  console.log("LP WETH:", await liquidityProvider.WETH());
  console.log("LP factory:", await liquidityProvider.factory());

  console.log("\n========== UPGRADE COMPLETE ==========");
  console.log(`MockWETH:     ${await weth.getAddress()}`);
  console.log(`MockFactory:  ${await factory.getAddress()}`);
  console.log(`MockRouter:   ${await router.getAddress()}`);
  console.log(`LaunchPad:    ${LAUNCHPAD_PROXY} (upgraded)`);
  console.log(`LiquidityProvider: ${LIQUIDITY_PROVIDER_PROXY} (upgraded)`);
  console.log(`Remaining balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH`);
}

main().catch(console.error);
