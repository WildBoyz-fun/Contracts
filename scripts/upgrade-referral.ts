import { ethers, upgrades } from "hardhat";

async function main() {
  const PROXY = "0x5f04FEc5493DE9A11229559854492a8Cea7950dE";
  console.log("Upgrading ReferralTracker at", PROXY);
  const Factory = await ethers.getContractFactory("ReferralTracker");
  await upgrades.upgradeProxy(PROXY, Factory, { kind: "uups" });
  console.log("ReferralTracker upgraded");
}

main().catch(console.error);
