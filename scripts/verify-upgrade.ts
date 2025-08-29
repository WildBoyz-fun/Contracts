import { ethers } from "hardhat";

async function main() {
  const proxyAddress = process.env.PROXY_ADDRESS;
  
  if (!proxyAddress) {
    throw new Error("Please set PROXY_ADDRESS environment variable");
  }
  
  console.log(`Verifying LaunchPad proxy at: ${proxyAddress}`);
  
  // Connect to the proxy
  const proxy = await ethers.getContractAt("LaunchPadUpgradeable", proxyAddress);
  
  // Check basic functionality
  console.log("\n=== Basic Information ===");
  console.log(`Current implementation: ${await proxy.getImplementation()}`);
  console.log(`Contract owner: ${await proxy.owner()}`);
  console.log(`Target fund raising amount: ${await proxy.targetFundRasingAmount()}`);
  console.log(`Fee rate: ${await proxy._feeRate()}%`);
  console.log(`Max gas price: ${await proxy.getMaxGasPrice()}`);
  console.log(`Total contract count: ${await proxy.totalContractCount()}`);
  
  // Check contract balance
  const balance = await proxy.getBalance();
  console.log(`Contract balance: ${ethers.formatEther(balance)} ETH`);
  
  // Check launched tokens
  const launchedTokens = await proxy.getLaunchedTokenContracts();
  console.log(`Launched tokens count: ${launchedTokens.length}`);
  
  if (launchedTokens.length > 0) {
    console.log("\n=== Launched Tokens ===");
    for (let i = 0; i < Math.min(launchedTokens.length, 5); i++) {
      const token = launchedTokens[i];
      console.log(`Token ${i + 1}:`);
      console.log(`  Address: ${token.tokenAddress}`);
      console.log(`  Symbol: ${token.symbol}`);
      console.log(`  Name: ${token.name}`);
      
      // Get contract info
      const contractInfo = await proxy.contractInfo(token.tokenAddress);
      console.log(`  Is Active: ${contractInfo.saleIsActive}`);
      console.log(`  Total Supply: ${ethers.formatEther(contractInfo.totalSupply)}`);
      console.log(`  ETH Balance: ${ethers.formatEther(contractInfo.ethDepositBalance)}`);
    }
  }
  
  console.log("\n✅ Verification completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });