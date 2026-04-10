import { ethers, upgrades } from "hardhat";

/**
 * Security upgrade script:
 * - LaunchPad: pause mechanism, sweepDust pagination, min deposit, referral event
 * - ReferralTracker: int256 bounds, reentrancy guard
 * - TokenFactory: TokenCreated event
 */

const LAUNCHPAD_PROXY = "0x4844874dDeC2C0b5040130515b8aA91861483aA8";
const REFERRAL_TRACKER_PROXY = "0x5f04FEc5493DE9A11229559854492a8Cea7950dE";
const TOKEN_FACTORY_PROXY = "0x7F2ABF905E78c50774d458271Ad18810a06F57a3";
const ERC404_IMPL_OLD = "0x3460e95bD609A3c15E8C0809A8b899583625106c";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);
  console.log("Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");

  // 1. Upgrade LaunchPad
  console.log("\n--- Upgrading LaunchPad (security) ---");
  const LaunchPad = await ethers.getContractFactory("LaunchPad");
  const launchPad = await upgrades.upgradeProxy(LAUNCHPAD_PROXY, LaunchPad);
  await launchPad.waitForDeployment();
  console.log("LaunchPad upgraded at:", LAUNCHPAD_PROXY);

  // 2. Upgrade ReferralTracker
  console.log("\n--- Upgrading ReferralTracker (security) ---");
  const ReferralTracker = await ethers.getContractFactory("ReferralTracker");
  const referralTracker = await upgrades.upgradeProxy(REFERRAL_TRACKER_PROXY, ReferralTracker);
  await referralTracker.waitForDeployment();
  console.log("ReferralTracker upgraded at:", REFERRAL_TRACKER_PROXY);

  // 3. Upgrade TokenFactory
  console.log("\n--- Upgrading TokenFactory (security) ---");
  const TokenFactory = await ethers.getContractFactory("TokenFactory");
  const tokenFactory = await upgrades.upgradeProxy(TOKEN_FACTORY_PROXY, TokenFactory);
  await tokenFactory.waitForDeployment();
  console.log("TokenFactory upgraded at:", TOKEN_FACTORY_PROXY);

  // 4. Deploy new ERC404Token implementation (with uint16 overflow fix)
  console.log("\n--- Deploying new ERC404Token implementation ---");
  const erc404Impl = await (await ethers.deployContract("ERC404Token")).waitForDeployment();
  const newImplAddr = await erc404Impl.getAddress();
  console.log("New ERC404Token impl:", newImplAddr);

  // Update TokenFactory to use new implementation
  await (await tokenFactory.setImplementation(newImplAddr)).wait();
  console.log("TokenFactory implementation updated");

  // Verify
  console.log("\n========== SECURITY UPGRADE COMPLETE ==========");
  console.log(`LaunchPad:       ${LAUNCHPAD_PROXY} (upgraded)`);
  console.log(`ReferralTracker: ${REFERRAL_TRACKER_PROXY} (upgraded)`);
  console.log(`TokenFactory:    ${TOKEN_FACTORY_PROXY} (upgraded)`);
  console.log(`ERC404Token:     ${newImplAddr} (new impl)`);
  console.log(`Remaining: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH`);
}

main().catch(console.error);
