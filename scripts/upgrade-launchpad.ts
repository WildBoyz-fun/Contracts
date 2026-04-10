import { ethers, upgrades } from "hardhat";

async function main() {
  const PROXY = "0x4844874dDeC2C0b5040130515b8aA91861483aA8";
  console.log("Upgrading LaunchPad at", PROXY);

  const LaunchPadV2 = await ethers.getContractFactory("LaunchPad");
  const upgraded = await upgrades.upgradeProxy(PROXY, LaunchPadV2, { kind: "uups" });
  await upgraded.waitForDeployment();
  console.log("LaunchPad upgraded successfully");
}

main().catch(console.error);
