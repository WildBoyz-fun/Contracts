
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import TokenTreasuryModule from "./TokenTreasury";
import BondingCurveModule from "./BondingCurve";
import OwnerGroupModule from "./OwnerGroup";

const LocalDevModule = buildModule("LocalDevModule", (m) => {
    // 1. Deploy Mocks
    const factory = m.contract("MockUniswapV2Factory");
    const weth = m.contract("MockWETH");
    const router = m.contract("MockUniswapV2Router", [factory, weth]);

    // 2. Core contracts
    const { tokenTreasury } = m.useModule(TokenTreasuryModule);
    const { bondingCurve } = m.useModule(BondingCurveModule);
    const { ownerGroupContract } = m.useModule(OwnerGroupModule);

    // 3. TokenFactory
    const tokenFactory = m.contract("TokenFactory", [ownerGroupContract]);

    // 4. LiquidityProvider
    const liquidityProvider = m.contract("LiquidityProvider", [router, ownerGroupContract]);

    // 5. ReferralTracker
    const referralTracker = m.contract("ReferralTracker", [ownerGroupContract]);

    // 6. LaunchPad
    const launchPad = m.contract("LaunchPad", [tokenTreasury, bondingCurve, ownerGroupContract]);

    // 7. Wire up all contracts
    m.call(launchPad, "setLiquidityProviderContract", [liquidityProvider]);
    m.call(launchPad, "setTokenFactory", [tokenFactory]);
    m.call(launchPad, "setReferralTrackerContract", [referralTracker]);
    m.call(liquidityProvider, "setLaunchPad", [launchPad]);
    m.call(tokenFactory, "setLaunchPad", [launchPad]);
    m.call(referralTracker, "setAuthorizedContract", [launchPad, true]);

    return {
        factory, weth, router,
        tokenTreasury, bondingCurve, ownerGroupContract,
        tokenFactory, liquidityProvider, referralTracker, launchPad
    };
});

export default LocalDevModule;
