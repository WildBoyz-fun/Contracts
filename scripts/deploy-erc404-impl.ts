import { ethers } from "hardhat";

async function main() {
  const erc404 = await (await ethers.deployContract("ERC404Token")).waitForDeployment();
  const addr = await erc404.getAddress();
  console.log("ERC404Token impl:", addr);

  const tf = await ethers.getContractAt("TokenFactory", "0x7F2ABF905E78c50774d458271Ad18810a06F57a3");
  await (await tf.setImplementation(addr)).wait();
  console.log("TokenFactory implementation updated to:", addr);
}

main().catch(console.error);
