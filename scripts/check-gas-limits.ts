import { ethers } from "hardhat";

async function main() {
  const launchPadAddress = "0x30A3D4408a4c09855203f8128b5a4cD42F5a5632";
  const userAddress = "0xf631eBDa5E854639EC8de7eD83d70F513011Cd3D";
  
  console.log("🔍 Checking gas price settings...");
  
  try {
    const launchPad = await ethers.getContractAt("LaunchPadUpgradeable", launchPadAddress);
    
    // 가스 가격 제한 확인
    const maxGasPrice = await launchPad.getMaxGasPrice();
    console.log(`Max allowed gas price: ${ethers.formatUnits(maxGasPrice, 'gwei')} gwei`);
    
    // 사용자 가스 가격 면제 여부 확인
    const isExempt = await launchPad.isGasPriceExempt(userAddress);
    console.log(`User ${userAddress} is exempt from gas price limits: ${isExempt}`);
    
    // 현재 네트워크 가스 가격 확인
    const feeData = await ethers.provider.getFeeData();
    console.log(`Current network gas price: ${ethers.formatUnits(feeData.gasPrice || 0, 'gwei')} gwei`);
    
    // 컨트랙트 소유자 확인
    const owner = await launchPad.owner();
    console.log(`Contract owner: ${owner}`);
    
    console.log("\n💡 해결 방법:");
    console.log("1. 가스 가격을 낮춰서 거래 (2 gwei 이하)");
    console.log("2. 또는 컨트랙트 소유자가 가스 가격 제한 증가");
    console.log("3. 또는 사용자를 가스 가격 면제 목록에 추가");
    
  } catch (error) {
    console.error(`❌ Error: ${error}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });