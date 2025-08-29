// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import TokenTreasuryModule from "./TokenTreasury";
import BondingCurveModule from "./BondingCurve";
import OwnerGroupModule from "./OwnerGroup";

const LaunchPadUpgradeableModule = buildModule("LaunchPadUpgradeableModule", (m) => {
  
  const { tokenTreasury } = m.useModule(TokenTreasuryModule);
  const { bondingCurve } = m.useModule(BondingCurveModule);
  const { ownerGroupContract } = m.useModule(OwnerGroupModule);

  // Deploy the implementation contract
  const launchPadImpl = m.contract("LaunchPadUpgradeable");

  // Encode the initialize function call
  const initData = m.encodeFunctionCall(launchPadImpl, "initialize", [
    tokenTreasury, 
    bondingCurve, 
    ownerGroupContract
  ]);

  // Deploy the ERC1967 Proxy
  const proxy = m.contract("@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy", [
    launchPadImpl,
    initData
  ]);

  // Create a contract instance pointing to the proxy address but using the implementation ABI
  const launchPadProxy = m.contractAt("LaunchPadUpgradeable", proxy, { id: "LaunchPadProxy" });

  console.log(`LaunchPadUpgradeable Implementation: ${launchPadImpl}`);
  console.log(`LaunchPadUpgradeable Proxy: ${proxy}`);

  return { 
    launchPadImpl,
    proxy,
    launchPadProxy,
    launchPad: launchPadProxy // Alias for compatibility
  };
});

export default LaunchPadUpgradeableModule;