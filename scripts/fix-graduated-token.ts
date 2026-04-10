import { ethers } from "hardhat";

const LAUNCHPAD = "0x4844874dDeC2C0b5040130515b8aA91861483aA8";
const TOKEN = "0x61CfbB0ee612F8EA51a17CA36845F11e7372B3e3";

async function main() {
  const [deployer] = await ethers.getSigners();
  const launchPad = await ethers.getContractAt("LaunchPad", LAUNCHPAD);
  const token = await ethers.getContractAt("IERC20", TOKEN);

  // Check current state
  const fees = await launchPad.totalAccumulatedFees();
  const tokenBal = await token.balanceOf(LAUNCHPAD);
  const ethBal = await ethers.provider.getBalance(LAUNCHPAD);

  console.log("=== Current State ===");
  console.log("Accumulated fees:", ethers.formatEther(fees), "ETH");
  console.log("LaunchPad ETH balance:", ethers.formatEther(ethBal));
  console.log("Token in LaunchPad:", ethers.formatEther(tokenBal));
  console.log("Deployer balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)));

  // We need ETH to create LP. Options:
  // 1. Use accumulated fees (if enough)
  // 2. Send ETH to LaunchPad and use addLiquidityETH

  // If fees are not enough, we can send some ETH to LaunchPad first
  // Then call addLiquidityETH with a portion of the tokens

  const targetEth = ethers.parseEther("0.005"); // small amount for testnet LP
  const targetTokens = ethers.parseEther("50000000"); // 50M tokens for LP

  if (fees < targetEth) {
    console.log("\nInsufficient fees. Sending ETH to LaunchPad...");
    // Send ETH to LaunchPad to cover LP creation
    const tx = await deployer.sendTransaction({
      to: LAUNCHPAD,
      value: targetEth,
    });
    await tx.wait();
    console.log("Sent", ethers.formatEther(targetEth), "ETH to LaunchPad");

    // The ETH goes to the contract but isn't in totalAccumulatedFees
    // We need a different approach - directly call addLiquidityETH won't work
    // because it checks totalAccumulatedFees

    console.log("\nNote: addLiquidityETH requires ETH from totalAccumulatedFees.");
    console.log("For this graduated token, we may need a different recovery approach.");
    console.log("Consider adding a reGraduate function or manual LP creation.");
  } else {
    console.log("\nFees available. Creating LP with fees...");
    console.log("Using", ethers.formatEther(targetEth), "ETH and", ethers.formatEther(targetTokens), "tokens");

    try {
      const tx = await launchPad.addLiquidityETH(TOKEN, targetTokens, targetEth);
      const receipt = await tx.wait();
      console.log("LP created! TX:", receipt?.hash);

      const newPair = await launchPad.getGraduatedPair(TOKEN);
      console.log("New pair address:", newPair);
    } catch (e: any) {
      console.log("Failed:", e.message);
    }
  }
}

main().catch(console.error);
