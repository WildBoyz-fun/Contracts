import { ethers, upgrades } from "hardhat";

async function main() {
  console.log("Starting LaunchPad upgrade process...");
  
  // Proxy address
  const proxyAddress = process.env.PROXY_ADDRESS;
  
  if (!proxyAddress) {
    throw new Error("Please set PROXY_ADDRESS environment variable");
  }
  
  console.log(`Upgrading LaunchPad at proxy address: ${proxyAddress}`);
  
  // Get the deployer
  const [deployer] = await ethers.getSigners();
  console.log("Upgrading with account:", deployer.address);
  
  // Get the new implementation contract factory
  const LaunchPadUpgradeable = await ethers.getContractFactory("LaunchPadUpgradeable");
  
  // Upgrade the proxy
  console.log("Upgrading proxy to new implementation...");
  const upgraded = await upgrades.upgradeProxy(proxyAddress, LaunchPadUpgradeable);
  
  await upgraded.waitForDeployment();
  
  const newImplementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
  
  console.log("Upgrade completed successfully!");
  console.log(`Proxy address: ${proxyAddress}`);
  console.log(`New implementation address: ${newImplementationAddress}`);
  
  // Verify the upgrade worked by calling a function
  const proxy = await ethers.getContractAt("LaunchPadUpgradeable", proxyAddress);
  try {
    const totalCount = await proxy.totalContractCount();
    console.log(`Total contracts: ${totalCount}`);
    console.log("✅ Upgrade verification successful!");
  } catch (error) {
    console.log("❌ Upgrade verification failed:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });