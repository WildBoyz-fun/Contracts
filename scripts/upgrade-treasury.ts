import { ethers, upgrades } from "hardhat";

const LAUNCHPAD = "0x4844874dDeC2C0b5040130515b8aA91861483aA8";
const OWNER_GROUP = "0xbde4031df368BADf335cbeBECC5fE29fc00dedA0";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  // 1. Upgrade LaunchPad (add setTreasuryAddress)
  const LP = await ethers.getContractFactory("LaunchPad");
  await (await upgrades.upgradeProxy(LAUNCHPAD, LP)).waitForDeployment();
  console.log("LaunchPad upgraded");

  // 2. Deploy new Treasury with emergencyWithdrawETH
  const treasury = await (await ethers.deployContract("TokenTreasury", [OWNER_GROUP])).waitForDeployment();
  const treasuryAddr = await treasury.getAddress();
  console.log("New Treasury:", treasuryAddr);

  // 3. Update LaunchPad to point to new Treasury
  const launchPad = await ethers.getContractAt("LaunchPad", LAUNCHPAD);
  await (await launchPad.setTreasuryAddress(treasuryAddr)).wait();
  console.log("LaunchPad treasury updated");

  // Verify
  console.log("Verified treasury:", await launchPad.getTreasuryAddress());
  console.log("Remaining:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");
}

main().catch(console.error);
