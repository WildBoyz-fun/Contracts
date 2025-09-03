import { ethers } from "hardhat";

async function main() {
  const txHash = "0xaf355b4c1aa07b6336cd0e2cfcd6f5b0e5d29289b874c0b57354acec9e8a3c21";
  
  console.log(`🔍 Analyzing failed transaction: ${txHash}`);
  
  try {
    // 트랜잭션 정보 가져오기
    const tx = await ethers.provider.getTransaction(txHash);
    if (!tx) {
      console.log("❌ Transaction not found");
      return;
    }
    
    console.log("\n📋 Transaction Details:");
    console.log(`From: ${tx.from}`);
    console.log(`To: ${tx.to}`);
    console.log(`Value: ${ethers.formatEther(tx.value || 0)} ETH`);
    console.log(`Gas Limit: ${tx.gasLimit?.toString()}`);
    console.log(`Gas Price: ${ethers.formatUnits(tx.gasPrice || 0, 'gwei')} gwei`);
    console.log(`Data: ${tx.data?.slice(0, 42)}...`);
    
    // 트랜잭션 영수증 가져오기
    const receipt = await ethers.provider.getTransactionReceipt(txHash);
    if (receipt) {
      console.log("\n📄 Transaction Receipt:");
      console.log(`Status: ${receipt.status === 1 ? "Success" : "Failed"}`);
      console.log(`Gas Used: ${receipt.gasUsed.toString()}`);
      console.log(`Block Number: ${receipt.blockNumber}`);
      
      if (receipt.logs && receipt.logs.length > 0) {
        console.log(`\n📝 Logs (${receipt.logs.length}):`);
        receipt.logs.forEach((log, index) => {
          console.log(`  Log ${index}: ${log.address} - ${log.topics[0]}`);
        });
      }
    }
    
    // 트랜잭션 재실행하여 에러 확인
    if (receipt && receipt.status === 0) {
      console.log("\n🔄 Re-executing transaction to get error details...");
      try {
        await ethers.provider.call({
          to: tx.to,
          from: tx.from,
          data: tx.data,
          value: tx.value,
          gasLimit: tx.gasLimit,
          gasPrice: tx.gasPrice
        }, receipt.blockNumber - 1);
      } catch (error: any) {
        console.log("❌ Transaction failed with error:");
        console.log(error.message || error.toString());
        
        // 에러 메시지 파싱
        if (error.message) {
          if (error.message.includes("revert")) {
            const revertMatch = error.message.match(/revert (.+)/);
            if (revertMatch) {
              console.log(`🚨 Revert reason: ${revertMatch[1]}`);
            }
          }
        }
      }
    }
    
    // 컨트랙트 상태 확인
    if (tx.to) {
      console.log(`\n🏠 Contract Analysis for: ${tx.to}`);
      
      // LaunchPad 컨트랙트라면 상태 확인
      try {
        const launchPad = await ethers.getContractAt("LaunchPadUpgradeable", tx.to);
        
        // 기본 정보
        const totalContracts = await launchPad.totalContractCount();
        console.log(`Total contracts: ${totalContracts}`);
        
        // 함수 호출이 buyToken인지 확인
        if (tx.data && tx.data.startsWith("0x")) {
          const functionSelector = tx.data.slice(0, 10);
          console.log(`Function selector: ${functionSelector}`);
          
          // buyToken 함수 시그니처: buyToken(address)
          // 0x6ea056a9 = buyToken(address)
          if (functionSelector === "0x6ea056a9") {
            console.log("📞 Function called: buyToken(address)");
            
            // 토큰 주소 디코딩
            const tokenAddress = "0x" + tx.data.slice(34, 74);
            console.log(`Token address: ${tokenAddress}`);
            
            // 컨트랙트 정보 확인
            try {
              const contractInfo = await launchPad.contractInfo(tokenAddress);
              console.log(`\n📊 Token Contract Info:`);
              console.log(`Deployed by: ${contractInfo.deployedBy}`);
              console.log(`Sale active: ${contractInfo.saleIsActive}`);
              console.log(`Max supply: ${ethers.formatEther(contractInfo.maxSupply)}`);
              console.log(`Total supply: ${ethers.formatEther(contractInfo.totalSupply)}`);
              console.log(`ETH balance: ${ethers.formatEther(contractInfo.ethDepositBalance)}`);
              console.log(`Exists: ${contractInfo.exists}`);
              
              // 토큰 컨트랙트의 LaunchPad 잔액 확인
              const tokenContract = await ethers.getContractAt("ERC404Token", tokenAddress);
              const launchPadBalance = await tokenContract.balanceOf(tx.to);
              console.log(`LaunchPad token balance: ${ethers.formatEther(launchPadBalance)}`);
              
            } catch (err) {
              console.log(`❌ Error reading contract info: ${err}`);
            }
          }
        }
        
      } catch (contractError) {
        console.log(`❌ Not a LaunchPad contract or error: ${contractError}`);
      }
    }
    
  } catch (error) {
    console.error(`❌ Error analyzing transaction: ${error}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });