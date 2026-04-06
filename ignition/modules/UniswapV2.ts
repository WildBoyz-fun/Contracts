// Deploy Uniswap V2 Factory + WETH + Router on chains without existing deployments
// Usage: npx hardhat ignition deploy ignition/modules/UniswapV2.ts --network base_sepolia

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const UniswapV2Module = buildModule("UniswapV2Module", (m) => {
  // Deploy WETH
  const weth = m.contract("MockWETH");

  // Deploy Factory
  const factory = m.contract("MockUniswapV2Factory");

  // Deploy Router (needs factory + WETH)
  const router = m.contract("MockUniswapV2Router", [factory, weth]);

  return { weth, factory, router };
});

export default UniswapV2Module;
