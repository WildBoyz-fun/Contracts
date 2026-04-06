import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying LaunchPadView with:", deployer.address);

  const view = await (await ethers.deployContract("LaunchPadView")).waitForDeployment();
  console.log("LaunchPadView:", await view.getAddress());
}

main().catch(console.error);
