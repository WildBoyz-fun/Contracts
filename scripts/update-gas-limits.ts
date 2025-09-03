import { ethers } from "hardhat";

async function main() {
  const launchPadAddress = "0x30A3D4408a4c09855203f8128b5a4cD42F5a5632";
  
  console.log("🔧 Updating gas price limits...");
  
  try {
    const [signer] = await ethers.getSigners();
    console.log(`Using signer: ${signer.address}`);
    
    const launchPad = await ethers.getContractAt("LaunchPadUpgradeable", launchPadAddress);
    
    // 현재 설정 확인
    const currentMaxGasPrice = await launchPad.getMaxGasPrice();
    const owner = await launchPad.owner();
    
    console.log(`Current max gas price: ${ethers.formatUnits(currentMaxGasPrice, 'gwei')} gwei`);
    console.log(`Contract owner: ${owner}`);
    console.log(`Signer address: ${signer.address}`);
    
    if (signer.address.toLowerCase() !== owner.toLowerCase()) {
      console.log("❌ Signer is not the contract owner. Cannot update settings.");
      
      console.log("\n💡 Alternative solutions:");
      console.log("1. Use the contract owner account to update gas limits");
      console.log("2. Add user to gas price exemption list");
      console.log("3. Instruct users to use lower gas prices (2 gwei or less)");
      
      return;
    }
    
    // 가스 가격을 100 gwei로 증가 (모나드 네트워크에 적합)
    const newMaxGasPrice = ethers.parseUnits("100", "gwei");
    
    console.log(`Setting new max gas price to: ${ethers.formatUnits(newMaxGasPrice, 'gwei')} gwei`);
    
    const tx = await launchPad.setMaxGasPrice(newMaxGasPrice);
    console.log(`Transaction sent: ${tx.hash}`);
    
    await tx.wait();
    
    // 업데이트된 설정 확인
    const updatedMaxGasPrice = await launchPad.getMaxGasPrice();
    console.log(`✅ Updated max gas price: ${ethers.formatUnits(updatedMaxGasPrice, 'gwei')} gwei`);
    
    console.log("\n🎉 Gas price limit has been updated!");
    console.log("Users can now make transactions with higher gas prices.");
    
  } catch (error: any) {
    console.error(`❌ Error: ${error.message || error}`);
    
    if (error.message?.includes("Ownable: caller is not the owner")) {
      console.log("\n💡 The connected account is not the contract owner.");
      console.log("Please use the owner account or contact the contract owner.");
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });