// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import TokenTreasuryModule from "./TokenTreasury";
import BondingCurveModule from "./BondingCurve";
import OwnerGroupModule from "./OwnerGroup";
import ReferralTrackerModule from "./ReferralTracker";
import LaunchPadUpgradeableModule from "./LaunchPadUpgradeable";

const DeployContractUpgradeableModule = buildModule("DeployContractUpgradeableModule", (m) => {
  
  const { tokenTreasury } = m.useModule(TokenTreasuryModule);
  const { bondingCurve } = m.useModule(BondingCurveModule);
  const { ownerGroupContract } = m.useModule(OwnerGroupModule);
  const { referralTracker } = m.useModule(ReferralTrackerModule);
  const { launchPad, launchPadImpl, proxy } = m.useModule(LaunchPadUpgradeableModule);

  console.log(`All contracts deployed successfully!`);
  console.log(`TokenTreasury: ${tokenTreasury}`);
  console.log(`BondingCurve: ${bondingCurve}`);
  console.log(`OwnerGroupContract: ${ownerGroupContract}`);
  console.log(`ReferralTracker: ${referralTracker}`);
  console.log(`LaunchPad Implementation: ${launchPadImpl}`);
  console.log(`LaunchPad Proxy: ${proxy}`);

  return { 
    tokenTreasury,
    bondingCurve,
    ownerGroupContract,
    referralTracker,
    launchPad,
    launchPadImpl,
    proxy
  };
});

export default DeployContractUpgradeableModule;