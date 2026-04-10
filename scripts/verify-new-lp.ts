import { ethers } from "hardhat";

const TOKEN = "0x61CfbB0ee612F8EA51a17CA36845F11e7372B3e3";
const NEW_FACTORY = "0x5e8436801d78251e061Df4CDbC714CF68fCDA513";
const NEW_WETH = "0x8c1db1A2A4534C742E8881699fb838027EAC97E5";
const NEW_ROUTER = "0xC9584d04A7B09DfA7075Ae374aB2756953a6b3Eb";
const LP_PROVIDER = "0x953cb16A86c775D0F9662316F066B6271C5A4f14";

async function main() {
  const factory = await ethers.getContractAt("MockUniswapV2Factory", NEW_FACTORY);
  const newPair = await factory.getPair(TOKEN, NEW_WETH);
  console.log("New pair on new factory:", newPair);

  if (newPair !== ethers.ZeroAddress) {
    const lp = await ethers.getContractAt("MockLPToken", newPair);
    const reserves = await lp.getReserves();
    console.log("Reserve0:", ethers.formatEther(reserves[0]));
    console.log("Reserve1:", ethers.formatEther(reserves[1]));
    console.log("Token0:", await lp.token0());
    console.log("Token1:", await lp.token1());

    const token = await ethers.getContractAt("IERC20", TOKEN);
    console.log("Token balance in new pair:", ethers.formatEther(await token.balanceOf(newPair)));

    // Check LP balances
    const DEAD = "0x000000000000000000000000000000000000dEaD";
    console.log("LP burned (DEAD):", ethers.formatEther(await lp.balanceOf(DEAD)));
    console.log("LP in LP Provider:", ethers.formatEther(await lp.balanceOf(LP_PROVIDER)));

    // Test getAmountsOut
    const router = await ethers.getContractAt("MockUniswapV2Router", NEW_ROUTER);
    try {
      const amounts = await router.getAmountsOut(ethers.parseEther("0.001"), [NEW_WETH, TOKEN]);
      console.log("\n=== Swap Quote ===");
      console.log("0.001 ETH ->", ethers.formatEther(amounts[1]), "tokens");
    } catch (e: any) {
      console.log("getAmountsOut failed:", e.message);
    }
  }

  // Check LP provider graduation info
  const lpProvider = await ethers.getContractAt("LiquidityProvider", LP_PROVIDER);
  const pairFromLP = await lpProvider.getPairAddress(TOKEN);
  console.log("\nLP Provider pair:", pairFromLP);
}

main().catch(console.error);
