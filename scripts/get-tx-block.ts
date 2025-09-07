import { ethers } from "hardhat";

async function main() {
  const txHash = "0xb9f02642f467871310057403806bc22fdda16ec82c95b13279fc3995c26607dd";
  
  console.log(`🔍 Getting block number for transaction: ${txHash}`);
  
  try {
    // 트랜잭션 영수증 가져오기
    const receipt = await ethers.provider.getTransactionReceipt(txHash);
    
    if (!receipt) {
      console.log("❌ Transaction not found or not mined yet");
      return;
    }
    
    console.log(`\n📦 Block Number: ${receipt.blockNumber}`);
    console.log(`📄 Transaction Status: ${receipt.status === 1 ? "Success" : "Failed"}`);
    console.log(`⛽ Gas Used: ${receipt.gasUsed.toString()}`);
    
    // 트랜잭션 정보도 가져오기
    const tx = await ethers.provider.getTransaction(txHash);
    if (tx) {
      console.log(`\n📋 Transaction Details:`);
      console.log(`From: ${tx.from}`);
      console.log(`To: ${tx.to}`);
      console.log(`Value: ${ethers.formatEther(tx.value || 0)} ETH`);
      console.log(`Gas Price: ${ethers.formatUnits(tx.gasPrice || 0, 'gwei')} gwei`);
    }
    
    // 블록 정보
    const block = await ethers.provider.getBlock(receipt.blockNumber);
    if (block) {
      console.log(`\n🕒 Block Timestamp: ${new Date(Number(block.timestamp) * 1000).toISOString()}`);
      console.log(`📊 Block Hash: ${block.hash}`);
    }

    // ERC404 토큰 Transfer 이벤트 확인
    console.log(`\n📋 Transaction Logs (${receipt.logs.length} logs):`);
    
    const transferEventSignature = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"; // Transfer(address,address,uint256)
    
    let totalERC404Received = BigInt(0);
    let erc404TransferCount = 0;
    
    for (let i = 0; i < receipt.logs.length; i++) {
      const log = receipt.logs[i];
      console.log(`\n  Log ${i + 1}:`);
      console.log(`    Address: ${log.address}`);
      console.log(`    Topics: ${log.topics}`);
      
      // Transfer 이벤트 확인
      if (log.topics[0] === transferEventSignature && log.topics.length >= 3) {
        const from = ethers.getAddress("0x" + log.topics[1].slice(26));
        const to = ethers.getAddress("0x" + log.topics[2].slice(26));
        
        // 데이터가 비어있지 않은 경우에만 처리
        let value = BigInt(0);
        if (log.data && log.data !== "0x") {
          try {
            value = BigInt(log.data);
          } catch (error) {
            console.log(`      ⚠️ Could not parse data: ${log.data}`);
          }
        }
        
        console.log(`    🔄 Transfer Event Detected:`);
        console.log(`      From: ${from}`);
        console.log(`      To: ${to}`);
        console.log(`      Amount: ${ethers.formatEther(value)} tokens`);
        
        // 트랜잭션 보낸 주소로 전송된 토큰만 카운트
        if (to.toLowerCase() === tx?.from?.toLowerCase()) {
          totalERC404Received += value;
          erc404TransferCount++;
          console.log(`      ✅ This transfer is TO the transaction sender`);
        }
      }
    }
    
    if (erc404TransferCount > 0) {
      console.log(`\n🎯 ERC404 Token Summary:`);
      console.log(`   Total ERC404 tokens received: ${ethers.formatEther(totalERC404Received)}`);
      console.log(`   Number of token transfers: ${erc404TransferCount}`);
    } else {
      console.log(`\n❌ No ERC404 token transfers found to the transaction sender`);
    }
    
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