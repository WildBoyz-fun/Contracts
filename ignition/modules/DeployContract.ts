// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import  TokenTreasuryModule from "./TokenTreasury";
import BondingCurveModule from "./BondingCurve";
import OwnerGroupModule from "./OwnerGroup";

const LaunchPadModule = buildModule("LaunchPadModule", (m) => {
  
  const { tokenTreasury } = m.useModule(TokenTreasuryModule);
  const { bondingCurve } = m.useModule(BondingCurveModule);
  const { ownerGroupContract } = m.useModule(OwnerGroupModule);

  const launchPad = m.contract("LaunchPad", [tokenTreasury, bondingCurve, ownerGroupContract]);

  console.log(`LaunchPadContract: ${launchPad}`);

  return { launchPad };
});

export default LaunchPadModule;
