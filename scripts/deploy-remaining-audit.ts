import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  // 1. New OwnerGroup
  const og = await (await ethers.deployContract("OwnerGroupContract", [[deployer.address]])).waitForDeployment();
  const ogAddr = await og.getAddress();
  console.log("OwnerGroup:", ogAddr);

  // 2. Update all contracts
  const lp = await ethers.getContractAt("LaunchPad", "0x4844874dDeC2C0b5040130515b8aA91861483aA8");
  await (await lp.setOwnerGroup(ogAddr)).wait();
  console.log("LaunchPad updated");

  const lpP = await ethers.getContractAt("LiquidityProvider", "0x953cb16A86c775D0F9662316F066B6271C5A4f14");
  await (await lpP.setOwnerGroup(ogAddr)).wait();
  console.log("LiquidityProvider updated");

  const rt = await ethers.getContractAt("ReferralTracker", "0x5f04FEc5493DE9A11229559854492a8Cea7950dE");
  await (await rt.setOwnerGroup(ogAddr)).wait();
  console.log("ReferralTracker updated");

  const tf = await ethers.getContractAt("TokenFactory", "0x7F2ABF905E78c50774d458271Ad18810a06F57a3");
  await (await tf.setOwnerGroup(ogAddr)).wait();
  console.log("TokenFactory updated");

  // 3. New ERC404Token impl
  const erc404 = await (await ethers.deployContract("ERC404Token")).waitForDeployment();
  const implAddr = await erc404.getAddress();
  await (await tf.setImplementation(implAddr)).wait();
  console.log("ERC404Impl:", implAddr);

  console.log("\nDone. Remaining:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");
}
main().catch(console.error);
