import { ethers } from "hardhat";

const NEW_OG = "0x1451dddF926BfD6556a5E5989Ed3A3c3620A058D";
const LAUNCHPAD = "0x4844874dDeC2C0b5040130515b8aA91861483aA8";
const LP_PROVIDER = "0x953cb16A86c775D0F9662316F066B6271C5A4f14";
const REFERRAL = "0x5f04FEc5493DE9A11229559854492a8Cea7950dE";
const TOKEN_FACTORY = "0x7F2ABF905E78c50774d458271Ad18810a06F57a3";

async function main() {
  console.log("Updating OwnerGroup references to:", NEW_OG);

  const lp = await ethers.getContractAt("LaunchPad", LAUNCHPAD);
  await (await lp.setOwnerGroup(NEW_OG)).wait();
  console.log("LaunchPad done");

  const lpProvider = await ethers.getContractAt("LiquidityProvider", LP_PROVIDER);
  await (await lpProvider.setOwnerGroup(NEW_OG)).wait();
  console.log("LiquidityProvider done");

  const rt = await ethers.getContractAt("ReferralTracker", REFERRAL);
  await (await rt.setOwnerGroup(NEW_OG)).wait();
  console.log("ReferralTracker done");

  const tf = await ethers.getContractAt("TokenFactory", TOKEN_FACTORY);
  await (await tf.setOwnerGroup(NEW_OG)).wait();
  console.log("TokenFactory done");

  // Also update router
  const CURRENT_FACTORY = "0x5e8436801d78251e061Df4CDbC714CF68fCDA513";
  const CURRENT_WETH = "0x8c1db1A2A4534C742E8881699fb838027EAC97E5";
  const router = await (await ethers.deployContract("MockUniswapV2Router", [
    CURRENT_FACTORY, CURRENT_WETH
  ])).waitForDeployment();
  const newRouter = await router.getAddress();
  console.log("New MockRouter:", newRouter);
  await (await lpProvider.setRouter(newRouter)).wait();
  console.log("LiquidityProvider router updated");

  console.log("\nAll references updated.");
}

main().catch(console.error);
