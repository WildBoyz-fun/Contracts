// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const BondingCurveModule = buildModule("BondingCurveModule", (m) => {
  const bancorFormula = m.contract("BancorFormula");
  const bondingCurve = m.contract("BondingCurve", [bancorFormula]);

  console.log(`bondingCurve: ${bondingCurve}`)
  return { bondingCurve, bancorFormula };
});

export default BondingCurveModule;
