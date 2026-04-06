// Full deployment: Uniswap V2 + all LaunchPad contracts
// Usage: npx hardhat ignition deploy ignition/modules/FullDeploy.ts --network base_sepolia
//
// Use this when deploying to a chain WITHOUT existing Uniswap V2.
// For chains WITH existing Uniswap V2, use DeployContract.ts and set UNI_ROUTER_ADDRESS in .env

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import TokenTreasuryModule from "./TokenTreasury";
import BondingCurveModule from "./BondingCurve";
import OwnerGroupModule from "./OwnerGroup";

const FullDeployModule = buildModule("FullDeployModule", (m) => {
  // 1. Deploy Uniswap V2
  const weth = m.contract("MockWETH");
  const uniFactory = m.contract("MockUniswapV2Factory");
  const router = m.contract("MockUniswapV2Router", [uniFactory, weth]);

  // 2. Core modules
  const { tokenTreasury } = m.useModule(TokenTreasuryModule);
  const { bondingCurve } = m.useModule(BondingCurveModule);
  const { ownerGroupContract } = m.useModule(OwnerGroupModule);

  // 3. TokenFactory
  const tokenFactory = m.contract("TokenFactory", [ownerGroupContract]);

  // 4. LiquidityProvider (connected to our deployed router)
  const liquidityProvider = m.contract("LiquidityProvider", [router, ownerGroupContract]);

  // 5. ReferralTracker
  const referralTracker = m.contract("ReferralTracker", [ownerGroupContract]);

  // 6. LaunchPad
  const launchPad = m.contract("LaunchPad", [tokenTreasury, bondingCurve, ownerGroupContract]);

  // 7. Wire everything up
  m.call(launchPad, "setLiquidityProviderContract", [liquidityProvider]);
  m.call(launchPad, "setTokenFactory", [tokenFactory]);
  m.call(launchPad, "setReferralTrackerContract", [referralTracker]);
  m.call(liquidityProvider, "setLaunchPad", [launchPad]);
  m.call(tokenFactory, "setLaunchPad", [launchPad]);
  m.call(referralTracker, "setAuthorizedContract", [launchPad, true]);

  // 8. Set low graduation target for testnet testing (1000 tokens)
  m.call(launchPad, "setTargetFundRaisingAmount", [
    BigInt(1000) * BigInt(10 ** 18)  // 1000 tokens
  ]);

  return {
    weth, uniFactory, router,
    tokenTreasury, bondingCurve, ownerGroupContract,
    tokenFactory, liquidityProvider, referralTracker, launchPad,
  };
});

export default FullDeployModule;
