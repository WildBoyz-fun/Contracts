// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import * as dotenv from "dotenv";

dotenv.config();

const OwnerGroupModule = buildModule("OwnerGroupModule", (m) => {
  const ownerAddress = process.env.OWNER_ADDRESS;
  console.log(`ownerAddress : ${ownerAddress}`);
  
  if (!ownerAddress) {
    throw new Error("OWNER_ADDRESS environment variable is not set");
  }
  
  const ownerGroupContract = m.contract("OwnerGroupContract", [[ownerAddress]]);

  console.log(`OwnerGroupContract: ${ownerGroupContract}`)

  return { ownerGroupContract };
});

export default OwnerGroupModule;
