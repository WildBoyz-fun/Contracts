import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { vars } from "hardhat/config";

const OwnerGroupModule = buildModule("OwnerGroupModule", (m) => {
  const ownerAddress = vars.has("OWNER_ADDRESS") ? vars.get("OWNER_ADDRESS") : "";
  if (!ownerAddress) throw new Error("OWNER_ADDRESS not set. Run: npx hardhat vars set OWNER_ADDRESS");

  const ownerGroupContract = m.contract("OwnerGroupContract", [[ownerAddress]]);

  return { ownerGroupContract };
});

export default OwnerGroupModule;
