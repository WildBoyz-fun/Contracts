// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import * as dotenv from "dotenv";

dotenv.config();

const LiquidityProviderModule = buildModule("LiquidityProviderModule", (m) => {
  const routerAddress = process.env.UNI_ROUTER_ADDRESS;
  console.log(`routerAddress : ${routerAddress}`);
  const liquidityProvider = m.contract("LiquidityProvider", [routerAddress]);

  console.log(`liquidityProvider: ${liquidityProvider}`)

  return { liquidityProvider };
});

export default LiquidityProviderModule;
