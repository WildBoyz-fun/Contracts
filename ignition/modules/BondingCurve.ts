// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const BondingCurveModule = buildModule("BondingCurveModule", (m) => {
  const bondingCurve = m.contract("BondingCurve");

  console.log(`bondingCurve: ${bondingCurve}`)
  return { bondingCurve };
});

export default BondingCurveModule;
