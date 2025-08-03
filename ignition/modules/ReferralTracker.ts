import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import OwnerGroupModule from "./OwnerGroup";

const ReferralTrackerModule = buildModule("ReferralTrackerModule", (m) => {
  const { ownerGroupContract } = m.useModule(OwnerGroupModule);

  const referralTracker = m.contract("ReferralTracker", [ownerGroupContract]);

  console.log(`ReferralTracker Contract: ${referralTracker}`);

  return { referralTracker };
});

export default ReferralTrackerModule;