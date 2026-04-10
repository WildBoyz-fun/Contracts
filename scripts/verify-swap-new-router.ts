import { ethers } from "hardhat";

const TOKEN = "0x61CfbB0ee612F8EA51a17CA36845F11e7372B3e3";
const NEW_ROUTER = "0xF09cd9ADaB0D48294811ddF54590E5F3dA771a40";
const NEW_WETH = "0x8c1db1A2A4534C742E8881699fb838027EAC97E5";

async function main() {
  const router = await ethers.getContractAt("MockUniswapV2Router", NEW_ROUTER);

  // Test getAmountsOut with new router
  const amounts = await router.getAmountsOut(ethers.parseEther("0.001"), [NEW_WETH, TOKEN]);
  console.log("0.001 ETH ->", ethers.formatEther(amounts[1]), "tokens");
  console.log("Swap quote works on new router!");
}

main().catch(console.error);
