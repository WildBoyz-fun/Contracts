// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import * as dotenv from "dotenv";

dotenv.config();


// 1. Deploy TokenTreasuryContract
// 2. Deploy BondingCurveContract
// 3. Deploy OwnerGroupContract

const TokenTreasuryModule = buildModule("TokenTreasuryModule", (m) => {
  const ownerAddress = process.env.OWNER_ADDRESS;
  console.log(`ownerAddress : ${ownerAddress}`);
  const tokenTreasury = m.contract("TokenTreasury", [ownerAddress]);

  console.log(`tokenTreasury: ${tokenTreasury}`)

  return { tokenTreasury };
});

const BondingCurveModule = buildModule("BondingCurveModule", (m) => {
  const bondingCurve = m.contract("BondingCurve");

  console.log(`bondingCurve: ${bondingCurve}`)
  return { bondingCurve };
});

const OwnerGroupModule = buildModule("OwnerGroupModule", (m) => {
  const ownerAddress = process.env.OWNER_ADDRESS;
  console.log(`ownerAddress : ${ownerAddress}`);
  
  const ownerGroupContract = m.contract("OwnerGroupContract", [[ownerAddress]]);

  console.log(`OwnerGroupContract: ${ownerGroupContract}`)

  return { ownerGroupContract };
});

const LaunchPadModule = buildModule("LaunchPadModule", (m) => {
  

  const { tokenTreasury } = m.useModule(TokenTreasuryModule);
  const { bondingCurve } = m.useModule(BondingCurveModule);
  const { ownerGroupContract } = m.useModule(OwnerGroupModule);


  const launchPad = m.contract("LaunchPad", [tokenTreasury, bondingCurve, ownerGroupContract]);

  console.log(`LaunchPadContract: ${launchPad}`);

  return { launchPad };
});

export default LaunchPadModule;
