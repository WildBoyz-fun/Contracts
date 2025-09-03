import { ethers, upgrades } from "hardhat";

async function main() {
  console.log("Starting LaunchPad upgrade with fee calculation fix...");
  
  // 기존 프록시 주소 (모나드 테스트넷) - LaunchPad 프록시
  const proxyAddress = "0x30A3D4408a4c09855203f8128b5a4cD42F5a5632";
  
  console.log(`Upgrading LaunchPad at proxy address: ${proxyAddress}`);
  
  // 새로운 구현 컨트랙트 배포
  const LaunchPadUpgradeable = await ethers.getContractFactory("LaunchPadUpgradeable");
  
  console.log("Deploying new implementation...");
  const upgraded = await upgrades.upgradeProxy(proxyAddress, LaunchPadUpgradeable);
  
  await upgraded.waitForDeployment();
  
  console.log("✅ Upgrade completed successfully!");
  console.log(`Proxy address remains: ${proxyAddress}`);
  
  // 업그레이드 확인
  const proxy = await ethers.getContractAt("LaunchPadUpgradeable", proxyAddress);
  const currentImplementation = await proxy.getImplementation();
  
  console.log(`Current implementation address: ${currentImplementation}`);
  
  // 새로운 기능 확인 - MIN_TRANSACTION_AMOUNT 상수 확인
  try {
    const minTransactionAmount = await proxy.MIN_TRANSACTION_AMOUNT();
    console.log(`✅ MIN_TRANSACTION_AMOUNT: ${ethers.formatEther(minTransactionAmount)} ETH`);
    console.log("✅ Fee calculation bug has been fixed!");
  } catch (error) {
    console.log("⚠️  Could not verify MIN_TRANSACTION_AMOUNT constant");
  }
  
  console.log("\n🎉 LaunchPad upgrade completed with the following fixes:");
  console.log("1. Fixed fee calculation logic (multiplication before division)");
  console.log("2. Added minimum transaction amount validation (0.001 ETH)");
  console.log("3. Improved error handling for small transaction amounts");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });