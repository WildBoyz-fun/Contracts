// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import * as dotenv from "dotenv";

dotenv.config();

const TokenTreasuryModule = buildModule("TokenTreasuryModule", (m) => {
  const ownerAddress = process.env.OWNER_ADDRESS;
  console.log(`ownerAddress : ${ownerAddress}`);
  const tokenTreasury = m.contract("TokenTreasury", [ownerAddress]);

  console.log(`tokenTreasury: ${tokenTreasury}`)

  return { tokenTreasury };
});

export default TokenTreasuryModule;
