import { ethers, upgrades } from "hardhat";

const LAUNCHPAD_PROXY = "0x4844874dDeC2C0b5040130515b8aA91861483aA8";
const LP_PROVIDER_PROXY = "0x953cb16A86c775D0F9662316F066B6271C5A4f14";
const REFERRAL_TRACKER_PROXY = "0x5f04FEc5493DE9A11229559854492a8Cea7950dE";
const TOKEN_FACTORY_PROXY = "0x7F2ABF905E78c50774d458271Ad18810a06F57a3";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);
  console.log("Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");

  // 1. Deploy new OwnerGroupContract with multisig
  console.log("\n--- Deploying new OwnerGroupContract (with multisig) ---");
  const ownerGroup = await (await ethers.deployContract("OwnerGroupContract", [
    [deployer.address],
  ])).waitForDeployment();
  const newOGAddr = await ownerGroup.getAddress();
  console.log("New OwnerGroupContract:", newOGAddr);
  console.log("Required confirmations:", (await ownerGroup.requiredConfirmations()).toString());

  // 2. Upgrade all proxy contracts (to add setOwnerGroup)
  console.log("\n--- Upgrading proxy contracts ---");

  const LaunchPad = await ethers.getContractFactory("LaunchPad");
  const launchPad = await upgrades.upgradeProxy(LAUNCHPAD_PROXY, LaunchPad);
  await launchPad.waitForDeployment();
  console.log("LaunchPad upgraded");

  const LP = await ethers.getContractFactory("LiquidityProvider");
  const lp = await upgrades.upgradeProxy(LP_PROVIDER_PROXY, LP);
  await lp.waitForDeployment();
  console.log("LiquidityProvider upgraded");

  const RT = await ethers.getContractFactory("ReferralTracker");
  const rt = await upgrades.upgradeProxy(REFERRAL_TRACKER_PROXY, RT);
  await rt.waitForDeployment();
  console.log("ReferralTracker upgraded");

  const TF = await ethers.getContractFactory("TokenFactory");
  const tf = await upgrades.upgradeProxy(TOKEN_FACTORY_PROXY, TF);
  await tf.waitForDeployment();
  console.log("TokenFactory upgraded");

  // 3. Point all contracts to new OwnerGroup
  console.log("\n--- Updating OwnerGroup references ---");
  await (await launchPad.setOwnerGroup(newOGAddr)).wait();
  console.log("LaunchPad -> new OwnerGroup");

  await (await lp.setOwnerGroup(newOGAddr)).wait();
  console.log("LiquidityProvider -> new OwnerGroup");

  await (await rt.setOwnerGroup(newOGAddr)).wait();
  console.log("ReferralTracker -> new OwnerGroup");

  await (await tf.setOwnerGroup(newOGAddr)).wait();
  console.log("TokenFactory -> new OwnerGroup");

  // 4. Deploy new MockRouter with onlyOwner
  console.log("\n--- Deploying new MockRouter (with onlyOwner) ---");
  const CURRENT_FACTORY = "0x5e8436801d78251e061Df4CDbC714CF68fCDA513";
  const CURRENT_WETH = "0x8c1db1A2A4534C742E8881699fb838027EAC97E5";
  const router = await (await ethers.deployContract("MockUniswapV2Router", [
    CURRENT_FACTORY, CURRENT_WETH
  ])).waitForDeployment();
  const newRouterAddr = await router.getAddress();
  console.log("New MockRouter:", newRouterAddr);

  await (await lp.setRouter(newRouterAddr)).wait();
  console.log("LiquidityProvider router updated");

  console.log("\n========== MULTISIG DEPLOYMENT COMPLETE ==========");
  console.log(`OwnerGroupContract: ${newOGAddr} (with multisig proposals)`);
  console.log(`MockRouter:         ${newRouterAddr} (with onlyOwner)`);
  console.log(`Remaining: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH`);
}

main().catch(console.error);
