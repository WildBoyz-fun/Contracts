import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import OwnerGroupModule from "./OwnerGroup";

const TokenTreasuryModule = buildModule("TokenTreasuryModule", (m) => {
  const { ownerGroupContract } = m.useModule(OwnerGroupModule);
  const tokenTreasury = m.contract("TokenTreasury", [ownerGroupContract]);

  return { tokenTreasury };
});

export default TokenTreasuryModule;
