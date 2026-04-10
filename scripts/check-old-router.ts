import { ethers } from "hardhat";

const TOKEN = "0x61CfbB0ee612F8EA51a17CA36845F11e7372B3e3";
const OLD_ROUTER = "0x6B92c81c0dDEe2DA83E3aC95192e37Ab42A2BEd0";
const OLD_PAIR = "0xbdB9847C446E881fBfa902b0c07587253d6B42a1";
const LP_PROVIDER = "0x953cb16A86c775D0F9662316F066B6271C5A4f14";
const LAUNCHPAD = "0x4844874dDeC2C0b5040130515b8aA91861483aA8";
const DEAD = "0x000000000000000000000000000000000000dEaD";

async function main() {
  const token = await ethers.getContractAt("IERC20", TOKEN);

  console.log("=== Token balances ===");
  console.log("Old Router:", ethers.formatEther(await token.balanceOf(OLD_ROUTER)));
  console.log("Old Pair:", ethers.formatEther(await token.balanceOf(OLD_PAIR)));
  console.log("LP Provider:", ethers.formatEther(await token.balanceOf(LP_PROVIDER)));
  console.log("LaunchPad:", ethers.formatEther(await token.balanceOf(LAUNCHPAD)));
  console.log("Dead addr:", ethers.formatEther(await token.balanceOf(DEAD)));

  // Check ETH balances
  console.log("\n=== ETH balances ===");
  console.log("Old Router:", ethers.formatEther(await ethers.provider.getBalance(OLD_ROUTER)));
  console.log("Old Pair:", ethers.formatEther(await ethers.provider.getBalance(OLD_PAIR)));
  console.log("LP Provider:", ethers.formatEther(await ethers.provider.getBalance(LP_PROVIDER)));
  console.log("LaunchPad:", ethers.formatEther(await ethers.provider.getBalance(LAUNCHPAD)));

  // Check LP token (pair) balances
  const lp = await ethers.getContractAt("IERC20", OLD_PAIR);
  console.log("\n=== LP Token balances ===");
  console.log("Dead addr:", ethers.formatEther(await lp.balanceOf(DEAD)));
  console.log("LP Provider:", ethers.formatEther(await lp.balanceOf(LP_PROVIDER)));
  console.log("LaunchPad:", ethers.formatEther(await lp.balanceOf(LAUNCHPAD)));
}

main().catch(console.error);
