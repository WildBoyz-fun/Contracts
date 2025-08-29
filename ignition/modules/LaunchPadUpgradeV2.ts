// This setup uses Hardhat Ignition to manage smart contract upgrades.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const LaunchPadUpgradeV2Module = buildModule("LaunchPadUpgradeV2Module", (m) => {
  
  // Get the existing proxy address from previous deployment
  const proxyAddress = m.getParameter("proxyAddress");
  
  // Deploy new implementation contract
  const launchPadImplV2 = m.contract("LaunchPadUpgradeable");
  
  // Get the proxy contract instance
  const proxy = m.contractAt("LaunchPadUpgradeable", proxyAddress);
  
  // Upgrade the proxy to point to new implementation
  m.call(proxy, "upgradeToAndCall", [launchPadImplV2, "0x"], {
    from: m.getAccount(0), // Should be owner
  });

  console.log(`LaunchPadUpgradeable New Implementation: ${launchPadImplV2}`);
  console.log(`Upgraded Proxy: ${proxyAddress}`);

  return { 
    launchPadImplV2,
    proxy,
    launchPad: proxy
  };
});

export default LaunchPadUpgradeV2Module;