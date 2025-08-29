import { ethers, upgrades, ignition } from "hardhat";
import TokenTreasuryModule from "../ignition/modules/TokenTreasury";
import BondingCurveModule from "../ignition/modules/BondingCurve";
import OwnerGroupModule from "../ignition/modules/OwnerGroup";
import ReferralTrackerModule from "../ignition/modules/ReferralTracker";

async function main() {
  console.log("Starting upgradeable contracts deployment...");
  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());
  
  // Use existing deployed contracts (production-v12)
  console.log("\n=== Using Existing Dependencies ===");
  const existingAddresses = {
    tokenTreasury: "0xE659bf63dCC36cf087b4B3fd3268A1DC044a942B",
    bondingCurve: "0xda4d06cB7b0a7089569F51a30276Fd7B612c42F7",
    ownerGroupContract: "0x735F24B0c07A57e101AeeDA8b33E28B6bCEEA263",
    referralTracker: "0x3890ACdb4359ad538EA04879240D1b40Ae619ADE"
  };

  console.log(`TokenTreasury: ${existingAddresses.tokenTreasury}`);
  console.log(`BondingCurve: ${existingAddresses.bondingCurve}`);
  console.log(`OwnerGroupContract: ${existingAddresses.ownerGroupContract}`);
  console.log(`ReferralTracker: ${existingAddresses.referralTracker}`);

  // Deploy upgradeable LaunchPad using OpenZeppelin upgrades plugin
  console.log("\n=== Deploying LaunchPad Upgradeable ===");
  const LaunchPadUpgradeable = await ethers.getContractFactory("LaunchPadUpgradeable");
  
  const launchPadProxy = await upgrades.deployProxy(LaunchPadUpgradeable, [
    existingAddresses.tokenTreasury,
    existingAddresses.bondingCurve,
    existingAddresses.ownerGroupContract
  ], { initializer: 'initialize' });
  
  await launchPadProxy.waitForDeployment();
  
  const proxyAddress = await launchPadProxy.getAddress();
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
  
  console.log(`LaunchPad Implementation: ${implementationAddress}`);
  console.log(`LaunchPad Proxy: ${proxyAddress}`);
  
  // Save addresses for future reference
  const addresses = {
    tokenTreasury: existingAddresses.tokenTreasury,
    bondingCurve: existingAddresses.bondingCurve,
    ownerGroupContract: existingAddresses.ownerGroupContract,
    referralTracker: existingAddresses.referralTracker,
    launchPadImpl: implementationAddress,
    launchPadProxy: proxyAddress
  };
  
  console.log("\n=== Contract Addresses (JSON) ===");
  console.log(JSON.stringify(addresses, null, 2));
  
  // Verify proxy functionality
  console.log("\n=== Verification ===");
  console.log(`Target fund raising amount: ${await launchPadProxy.targetFundRasingAmount()}`);
  console.log(`Fee rate: ${await launchPadProxy._feeRate()}%`);
  console.log(`Contract owner: ${await launchPadProxy.owner()}`);
  console.log(`Max gas price: ${await launchPadProxy.getMaxGasPrice()}`);
  
  console.log("✅ Upgradeable deployment completed successfully!");
  console.log(`\n🎯 Use this proxy address for all interactions: ${proxyAddress}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });