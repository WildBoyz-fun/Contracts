// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import {vars} from "hardhat/config";

const SCALE: bigint = 1_000_000_000_000_000_000n;
const OWNER_ADDRESS = vars.get("OWNER");
const INITIAL_MINT: bigint = 1_000_000n * SCALE;

const TokenModule = buildModule("TokenModule", (m) => {
  const token = m.contract("MyToken", [OWNER_ADDRESS]);

  return { token };
});

const BondingCurveSwapModule = buildModule("BondingCurveModule", (m) => {
  const { token } = m.useModule(TokenModule);

  const swap = m.contract("BondingCurveSwap", [token]);

  m.call(token, "initialMint", [swap, INITIAL_MINT]);

  return { swap };
});

export default BondingCurveSwapModule;
