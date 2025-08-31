import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ReferralTrackerUpgradeableModule = buildModule("ReferralTrackerUpgradeableModule", (m) => {
  // 기존 배포된 OwnerGroup 컨트랙트 주소
  const ownerGroupAddress = "0x735F24B0c07A57e101AeeDA8b33E28B6bCEEA263";
  
  // 초기 소유자 주소 (OwnerGroup의 멤버 중 하나)
  // 실제 배포 시 적절한 주소로 변경 필요
  const initialOwner = "0x735F24B0c07A57e101AeeDA8b33E28B6bCEEA263"; // OwnerGroup 주소로 임시 설정

  // 1. Implementation 컨트랙트 배포
  const referralTrackerImpl = m.contract("ReferralTrackerUpgradeable", [], {
    id: "ReferralTrackerImpl"
  });

  // 2. 초기화 데이터 인코딩
  const initializeCalldata = m.encodeFunctionCall(
    referralTrackerImpl,
    "initialize",
    [ownerGroupAddress, initialOwner]
  );

  // 3. ERC1967Proxy 배포
  const proxy = m.contract("@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy", [
    referralTrackerImpl,
    initializeCalldata
  ], {
    id: "Proxy"
  });

  return { 
    referralTrackerImpl,
    proxy 
  };
});

export default ReferralTrackerUpgradeableModule;