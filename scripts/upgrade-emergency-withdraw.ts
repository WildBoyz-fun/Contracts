import { ethers, upgrades } from "hardhat";

const LAUNCHPAD_PROXY = "0x4844874dDeC2C0b5040130515b8aA91861483aA8";
const LP_PROVIDER_PROXY = "0x953cb16A86c775D0F9662316F066B6271C5A4f14";
const REFERRAL_TRACKER_PROXY = "0x5f04FEc5493DE9A11229559854492a8Cea7950dE";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  console.log("--- Upgrading LaunchPad (emergency withdraw) ---");
  const LaunchPad = await ethers.getContractFactory("LaunchPad");
  await (await upgrades.upgradeProxy(LAUNCHPAD_PROXY, LaunchPad)).waitForDeployment();
  console.log("LaunchPad upgraded");

  console.log("--- Upgrading LiquidityProvider (emergency withdraw) ---");
  const LP = await ethers.getContractFactory("LiquidityProvider");
  await (await upgrades.upgradeProxy(LP_PROVIDER_PROXY, LP)).waitForDeployment();
  console.log("LiquidityProvider upgraded");

  console.log("--- Upgrading ReferralTracker (emergency withdraw) ---");
  const RT = await ethers.getContractFactory("ReferralTracker");
  await (await upgrades.upgradeProxy(REFERRAL_TRACKER_PROXY, RT)).waitForDeployment();
  console.log("ReferralTracker upgraded");

  console.log("\nAll contracts upgraded with emergency withdraw functions.");
  console.log("Remaining:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");
}

main().catch(console.error);
