import { ethers } from "hardhat";

const LP_PROVIDER = "0x953cb16A86c775D0F9662316F066B6271C5A4f14";
const CURRENT_FACTORY = "0x5e8436801d78251e061Df4CDbC714CF68fCDA513";
const CURRENT_WETH = "0x8c1db1A2A4534C742E8881699fb838027EAC97E5";

async function main() {
  console.log("Deploying new MockRouter with emergency withdraw...");

  const router = await (await ethers.deployContract("MockUniswapV2Router", [
    CURRENT_FACTORY, CURRENT_WETH
  ])).waitForDeployment();

  const newRouterAddr = await router.getAddress();
  console.log("New MockRouter:", newRouterAddr);

  // Update LP Provider
  const lpProvider = await ethers.getContractAt("LiquidityProvider", LP_PROVIDER);
  await (await lpProvider.setRouter(newRouterAddr)).wait();
  console.log("LP Provider router updated to:", newRouterAddr);

  // Verify
  console.log("Verified router:", await lpProvider.router());
}

main().catch(console.error);
