// Production deployment script for oops4.fun LaunchPad
// Usage: npx hardhat ignition deploy ignition/modules/DeployContract.ts --network monad_testnet

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import TokenTreasuryModule from "./TokenTreasury";
import BondingCurveModule from "./BondingCurve";
import OwnerGroupModule from "./OwnerGroup";
import { vars } from "hardhat/config";

const DeployContractModule = buildModule("DeployContractModule", (m) => {
  // Core modules
  const { tokenTreasury } = m.useModule(TokenTreasuryModule);
  const { bondingCurve } = m.useModule(BondingCurveModule);
  const { ownerGroupContract } = m.useModule(OwnerGroupModule);

  // Uniswap Router address (from hardhat vars)
  const routerAddress = vars.has("UNI_ROUTER_ADDRESS") ? vars.get("UNI_ROUTER_ADDRESS") : "";
  if (!routerAddress) throw new Error("UNI_ROUTER_ADDRESS not set. Run: npx hardhat vars set UNI_ROUTER_ADDRESS");

  // 1. TokenFactory
  const tokenFactory = m.contract("TokenFactory", [ownerGroupContract]);

  // 2. LiquidityProvider
  const liquidityProvider = m.contract("LiquidityProvider", [routerAddress, ownerGroupContract]);

  // 3. ReferralTracker
  const referralTracker = m.contract("ReferralTracker", [ownerGroupContract]);

  // 4. LaunchPad
  const launchPad = m.contract("LaunchPad", [tokenTreasury, bondingCurve, ownerGroupContract]);

  // 5. Wire up all contracts
  m.call(launchPad, "setLiquidityProviderContract", [liquidityProvider]);
  m.call(launchPad, "setTokenFactory", [tokenFactory]);
  m.call(launchPad, "setReferralTrackerContract", [referralTracker]);
  m.call(liquidityProvider, "setLaunchPad", [launchPad]);
  m.call(tokenFactory, "setLaunchPad", [launchPad]);
  m.call(referralTracker, "setAuthorizedContract", [launchPad, true]);

  return {
    tokenTreasury, bondingCurve, ownerGroupContract,
    tokenFactory, liquidityProvider, referralTracker, launchPad
  };
});

export default DeployContractModule;
