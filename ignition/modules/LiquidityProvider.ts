// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import OwnerGroupModule from "./OwnerGroup";
import * as dotenv from "dotenv";

dotenv.config();

const LiquidityProviderModule = buildModule("LiquidityProviderModule", (m) => {
  const routerAddress = process.env.UNI_ROUTER_ADDRESS;
  console.log(`routerAddress : ${routerAddress}`);

  const { ownerGroupContract } = m.useModule(OwnerGroupModule);

  const liquidityProvider = m.contract("LiquidityProvider", [routerAddress, ownerGroupContract]);

  console.log(`liquidityProvider: ${liquidityProvider}`)

  return { liquidityProvider };
});

export default LiquidityProviderModule;
