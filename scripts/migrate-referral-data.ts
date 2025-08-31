import { ethers } from "hardhat";

interface ReferralActivity {
  activityType: number;
  point: bigint;
  timestamp: bigint;
}

async function main() {
  console.log("🔄 Starting ReferralTracker data migration...");

  // 주소 설정
  const LEGACY_REFERRAL_TRACKER = "0x3890ACdb4359ad538EA04879240D1b40Ae619ADE";
  const NEW_REFERRAL_TRACKER = "0x86bFf87de374124B98fd57B53972cc88D40ee393"; // 새 프록시 주소
  const NEW_LAUNCH_PAD = "0x30A3D4408a4c09855203f8128b5a4cD42F5a5632"; // 새 LaunchPad 프록시 주소

  // ABI 설정
  const legacyABI = [
    "function referrers(address) external view returns (address)",
    "function totalPoints(address) external view returns (int256)",
    "function accountRegistered(address) external view returns (bool)",
    "function getReferralHistory(address) external view returns (tuple(uint8 activityType, int256 point, uint256 timestamp)[])"
  ];

  const newABI = [
    "function batchRegisterReferrals(address[] users, address[] referrersList) external",
    "function batchSetTotalPoints(address[] users, int256[] points) external",
    "function batchAddHistory(address user, tuple(uint8 activityType, int256 point, uint256 timestamp)[] activities) external",
    "function setAuthorizedContract(address contractAddress, bool authorized) external",
    "function owner() external view returns (address)"
  ];

  // 컨트랙트 연결
  const [signer] = await ethers.getSigners();
  const legacyTracker = new ethers.Contract(LEGACY_REFERRAL_TRACKER, legacyABI, signer);
  const newTracker = new ethers.Contract(NEW_REFERRAL_TRACKER, newABI, signer);

  console.log("📍 Addresses:");
  console.log("  Legacy Tracker:", LEGACY_REFERRAL_TRACKER);
  console.log("  New Tracker:", NEW_REFERRAL_TRACKER);
  console.log("  New LaunchPad:", NEW_LAUNCH_PAD);
  console.log("  Signer:", signer.address);

  // 1. 먼저 새로운 LaunchPad를 authorized contract로 등록
  console.log("\n🔧 Step 1: Authorizing new LaunchPad...");
  try {
    const owner = await newTracker.owner();
    console.log("  New Tracker Owner:", owner);
    
    if (owner.toLowerCase() !== signer.address.toLowerCase()) {
      console.log("⚠️  Warning: Signer is not the owner. This might fail.");
    }

    const authTx = await newTracker.setAuthorizedContract(NEW_LAUNCH_PAD, true);
    await authTx.wait();
    console.log("✅ New LaunchPad authorized successfully");
  } catch (error) {
    console.error("❌ Failed to authorize new LaunchPad:", error);
    return;
  }

  // 2. 마이그레이션할 사용자 주소 리스트 (예시)
  // 실제로는 이벤트를 파싱하거나 다른 방법으로 사용자 목록을 가져와야 합니다
  const usersToMigrate = [
    // 예시 주소들 - 실제 사용자 주소로 교체 필요
    // "0x742d35Cc6636C0532925Fbb7B67f39b8AD4E3a65",
    // "0x8ba1f109551bD432803012645Hac136c8f6f1234",
    // 더 많은 주소들...
  ];

  if (usersToMigrate.length === 0) {
    console.log("⚠️  No users to migrate. Please add user addresses to the script.");
    console.log("   You can get user addresses from ReferralRegistered events.");
    return;
  }

  console.log(`\n📊 Step 2: Migrating ${usersToMigrate.length} users...`);

  // 배치별로 처리 (가스 한도 고려)
  const BATCH_SIZE = 10;
  const batches = [];
  for (let i = 0; i < usersToMigrate.length; i += BATCH_SIZE) {
    batches.push(usersToMigrate.slice(i, i + BATCH_SIZE));
  }

  for (let batchIndex = 0; batchIndex < batches.length; batchIndex++) {
    const batch = batches[batchIndex];
    console.log(`\n🔄 Processing batch ${batchIndex + 1}/${batches.length} (${batch.length} users)...`);

    try {
      // 각 배치의 데이터 수집
      const batchUsers: string[] = [];
      const batchReferrers: string[] = [];
      const batchPoints: bigint[] = [];

      for (const user of batch) {
        try {
          const referrer = await legacyTracker.referrers(user);
          const totalPoints = await legacyTracker.totalPoints(user);
          const isRegistered = await legacyTracker.accountRegistered(user);

          if (isRegistered && referrer !== ethers.ZeroAddress) {
            batchUsers.push(user);
            batchReferrers.push(referrer);
            batchPoints.push(totalPoints);
            console.log(`  ✓ ${user}: referrer=${referrer.substring(0, 6)}..., points=${totalPoints}`);
          } else {
            console.log(`  ⚠️ ${user}: not registered or no referrer`);
          }
        } catch (error) {
          console.error(`  ❌ Error reading data for ${user}:`, error);
        }
      }

      if (batchUsers.length > 0) {
        // 3. Referral 관계 마이그레이션
        console.log(`  📝 Migrating ${batchUsers.length} referral relationships...`);
        const referralTx = await newTracker.batchRegisterReferrals(batchUsers, batchReferrers);
        await referralTx.wait();
        console.log("  ✅ Referral relationships migrated");

        // 4. 포인트 마이그레이션
        console.log(`  🎯 Migrating ${batchUsers.length} point totals...`);
        const pointsTx = await newTracker.batchSetTotalPoints(batchUsers, batchPoints);
        await pointsTx.wait();
        console.log("  ✅ Points migrated");

        // 5. 히스토리 마이그레이션 (각 사용자별로)
        console.log(`  📚 Migrating histories for ${batchUsers.length} users...`);
        for (const user of batchUsers) {
          try {
            const history = await legacyTracker.getReferralHistory(user);
            if (history.length > 0) {
              const historyTx = await newTracker.batchAddHistory(user, history);
              await historyTx.wait();
              console.log(`    ✓ ${user}: ${history.length} history entries migrated`);
            }
          } catch (error) {
            console.error(`    ❌ Error migrating history for ${user}:`, error);
          }
        }
      }

    } catch (error) {
      console.error(`❌ Error processing batch ${batchIndex + 1}:`, error);
    }
  }

  console.log("\n🎉 Migration completed!");
  console.log("\n📋 Next steps:");
  console.log("1. Update frontend to use new ReferralTracker address");
  console.log("2. Test referral functionality with new contracts");
  console.log("3. Monitor for any issues");
  
  console.log("\n📍 New contract addresses:");
  console.log("- ReferralTracker (Proxy):", NEW_REFERRAL_TRACKER);
  console.log("- LaunchPad (Proxy):", NEW_LAUNCH_PAD);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });