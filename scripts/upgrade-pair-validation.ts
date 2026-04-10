import { ethers, upgrades } from "hardhat";
const LAUNCHPAD = "0x4844874dDeC2C0b5040130515b8aA91861483aA8";
async function main() {
  const LP = await ethers.getContractFactory("LaunchPad");
  await (await upgrades.upgradeProxy(LAUNCHPAD, LP)).waitForDeployment();
  console.log("LaunchPad upgraded (pair validation added)");
}
main().catch(console.error);
