import { ethers, upgrades } from "hardhat";

const LAUNCHPAD = "0x4844874dDeC2C0b5040130515b8aA91861483aA8";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  // 1. Upgrade LaunchPad (atomicity fix, refund pull pattern, pair check)
  const LP = await ethers.getContractFactory("LaunchPad");
  await (await upgrades.upgradeProxy(LAUNCHPAD, LP)).waitForDeployment();
  console.log("LaunchPad upgraded (audit fixes)");

  // 2. Deploy new OwnerGroup (proposal expiry fix)
  const og = await (await ethers.deployContract("OwnerGroupContract", [
    [deployer.address],
  ])).waitForDeployment();
  const ogAddr = await og.getAddress();
  console.log("New OwnerGroup:", ogAddr);

  // 3. Point LaunchPad to new OwnerGroup
  const launchPad = await ethers.getContractAt("LaunchPad", LAUNCHPAD);
  await (await launchPad.setOwnerGroup(ogAddr)).wait();
  console.log("LaunchPad -> new OwnerGroup");

  // 4. Point other contracts too
  const contracts = [
    { name: "LiquidityProvider", addr: "0x953cb16A86c775D0F9662316F066B6271C5A4f14" },
    { name: "ReferralTracker", addr: "0x5f04FEc5493DE9A11229559854492a8Cea7950dE" },
    { name: "TokenFactory", addr: "0x7F2ABF905E78c50774d458271Ad18810a06F57a3" },
  ];
  for (const c of contracts) {
    const contract = await ethers.getContractAt(c.name, c.addr);
    await (await contract.setOwnerGroup(ogAddr)).wait();
    console.log(`${c.name} -> new OwnerGroup`);
  }

  // 5. Deploy new ERC404Token impl
  const erc404 = await (await ethers.deployContract("ERC404Token")).waitForDeployment();
  const implAddr = await erc404.getAddress();
  const tf = await ethers.getContractAt("TokenFactory", "0x7F2ABF905E78c50774d458271Ad18810a06F57a3");
  await (await tf.setImplementation(implAddr)).wait();
  console.log("ERC404Token impl:", implAddr);

  console.log("\n=== AUDIT FIX DEPLOYMENT COMPLETE ===");
  console.log("OwnerGroup:", ogAddr);
  console.log("ERC404Impl:", implAddr);
  console.log("Remaining:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");
}

main().catch(console.error);
