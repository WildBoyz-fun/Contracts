import { ethers } from "hardhat";

const LAUNCHPAD = "0x4844874dDeC2C0b5040130515b8aA91861483aA8";
const LP_PROVIDER = "0x953cb16A86c775D0F9662316F066B6271C5A4f14";
const TOKEN = "0x61CfbB0ee612F8EA51a17CA36845F11e7372B3e3";

// Old router/factory (before upgrade)
const OLD_ROUTER = "0x6B92c81c0dDEe2DA83E3aC95192e37Ab42A2BEd0";

async function main() {
  const launchPad = await ethers.getContractAt("LaunchPad", LAUNCHPAD);
  const lpProvider = await ethers.getContractAt("LiquidityProvider", LP_PROVIDER);

  // Check graduation status
  const info = await launchPad.contractInfo(TOKEN);
  console.log("=== Token Info ===");
  console.log("deployedBy:", info[0]);
  console.log("saleIsActive:", info[1]);
  console.log("isGraduated:", info[2]);
  console.log("maxSupply:", ethers.formatEther(info[3]));
  console.log("totalSupply:", ethers.formatEther(info[4]));
  console.log("ethDepositBalance:", ethers.formatEther(info[5]));
  console.log("exists:", info[6]);

  // Check graduated pair
  const pair = await launchPad.getGraduatedPair(TOKEN);
  console.log("\nGraduated pair:", pair);

  // Check LP provider state
  const isGrad = await lpProvider.isGraduated(TOKEN);
  console.log("LP isGraduated:", isGrad);

  if (isGrad) {
    const gradInfo = await lpProvider.getGraduationInfo(TOKEN);
    console.log("Pair address:", gradInfo.pairAddress);
    console.log("Token amount:", ethers.formatEther(gradInfo.tokenAmount));
    console.log("ETH amount:", ethers.formatEther(gradInfo.ethAmount));
    console.log("LP burned:", ethers.formatEther(gradInfo.lpTokensBurned));
  }

  // Check current router/factory on LP provider
  const currentRouter = await lpProvider.router();
  const currentFactory = await lpProvider.factory();
  const currentWETH = await lpProvider.WETH();
  console.log("\n=== Current LP Provider Config ===");
  console.log("Router:", currentRouter);
  console.log("Factory:", currentFactory);
  console.log("WETH:", currentWETH);

  // Check if pair exists on NEW factory
  try {
    const newFactory = await ethers.getContractAt("MockUniswapV2Factory", currentFactory);
    const newPair = await newFactory.getPair(TOKEN, currentWETH);
    console.log("\nPair on NEW factory:", newPair);
  } catch (e: any) {
    console.log("\nNew factory getPair failed:", e.message);
  }

  // Check pair token balances (if pair exists)
  if (pair !== ethers.ZeroAddress) {
    try {
      const token = await ethers.getContractAt("IERC20", TOKEN);
      const pairBalance = await token.balanceOf(pair);
      console.log("\n=== Old Pair State ===");
      console.log("Token balance in pair:", ethers.formatEther(pairBalance));

      const lpToken = await ethers.getContractAt("MockLPToken", pair);
      const reserves = await lpToken.getReserves();
      console.log("Reserve0:", ethers.formatEther(reserves[0]));
      console.log("Reserve1:", ethers.formatEther(reserves[1]));
      console.log("Token0:", await lpToken.token0());
      console.log("Token1:", await lpToken.token1());
    } catch (e: any) {
      console.log("Pair query failed:", e.message);
    }
  }
}

main().catch(console.error);
