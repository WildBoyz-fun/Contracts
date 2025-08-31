import { ethers, upgrades } from "hardhat";

async function main() {
  console.log("Deploying ReferralTrackerUpgradeable...");

  // 기존 배포된 OwnerGroup 컨트랙트 주소
  const ownerGroupAddress = "0x735F24B0c07A57e101AeeDA8b33E28B6bCEEA263";
  
  // 초기 소유자 주소 (실제 배포 시 적절한 주소로 변경 필요)
  const initialOwner = "0x735F24B0c07A57e101AeeDA8b33E28B6bCEEA263"; // 임시로 OwnerGroup 주소 사용

  // 컨트랙트 팩토리 가져오기
  const ReferralTrackerUpgradeable = await ethers.getContractFactory("ReferralTrackerUpgradeable");

  console.log("Deploying proxy and implementation...");

  // 프록시와 함께 배포
  const referralTracker = await upgrades.deployProxy(
    ReferralTrackerUpgradeable,
    [ownerGroupAddress, initialOwner],
    { initializer: "initialize" }
  );

  await referralTracker.waitForDeployment();

  const proxyAddress = await referralTracker.getAddress();
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);

  console.log("✅ ReferralTrackerUpgradeable deployed:");
  console.log("📍 Proxy address:", proxyAddress);
  console.log("📍 Implementation address:", implementationAddress);

  // 배포 정보를 JSON 파일로 저장
  const deploymentInfo = {
    "ReferralTrackerUpgradeableModule#ReferralTrackerImpl": implementationAddress,
    "ReferralTrackerUpgradeableModule#Proxy": proxyAddress
  };

  console.log("\n📋 Deployment addresses:");
  console.log(JSON.stringify(deploymentInfo, null, 2));

  // 기본 설정 확인
  console.log("\n🔍 Verifying deployment...");
  
  try {
    const ownerGroup = await referralTracker.ownerGroup();
    const version = await referralTracker.version();
    const implementation = await referralTracker.getImplementation();
    
    console.log("✅ Owner Group:", ownerGroup);
    console.log("✅ Version:", version);
    console.log("✅ Implementation (from contract):", implementation);
  } catch (error) {
    console.error("❌ Error verifying deployment:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });