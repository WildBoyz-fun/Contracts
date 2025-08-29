import { ethers, ignition } from "hardhat";
import LaunchPadUpgradeV2Module from "../ignition/modules/LaunchPadUpgradeV2";

async function main() {
  console.log("Starting LaunchPad upgrade process...");
  
  // Get proxy address from previous deployment
  const proxyAddress = process.env.PROXY_ADDRESS;
  
  if (!proxyAddress) {
    throw new Error("Please set PROXY_ADDRESS environment variable");
  }
  
  console.log(`Upgrading LaunchPad at proxy address: ${proxyAddress}`);
  
  // Deploy new implementation and upgrade
  const { launchPadImplV2 } = await ignition.deploy(LaunchPadUpgradeV2Module, {
    parameters: {
      LaunchPadUpgradeV2Module: {
        proxyAddress: proxyAddress
      }
    }
  });
  
  console.log("Upgrade completed successfully!");
  console.log(`New implementation deployed at: ${await launchPadImplV2.getAddress()}`);
  console.log(`Proxy remains at: ${proxyAddress}`);
  
  // Verify the upgrade worked
  const proxy = await ethers.getContractAt("LaunchPadUpgradeable", proxyAddress);
  const currentImplementation = await proxy.getImplementation();
  
  console.log(`Current implementation address: ${currentImplementation}`);
  console.log(`Expected implementation address: ${await launchPadImplV2.getAddress()}`);
  
  if (currentImplementation.toLowerCase() === (await launchPadImplV2.getAddress()).toLowerCase()) {
    console.log("✅ Upgrade verification successful!");
  } else {
    console.log("❌ Upgrade verification failed!");
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });