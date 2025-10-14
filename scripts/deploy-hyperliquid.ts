import { ethers } from "hardhat";
import { config as loadEnv } from "dotenv";

loadEnv();

const GAS_LIMIT = 30_000_000n;
const FALLBACK_FEE = ethers.parseUnits("1", "gwei");
const MAX_FEE_PER_GAS = ethers.parseUnits("500", "gwei");
const PRIORITY_FEE = ethers.parseUnits("5", "gwei");

const getOverrides = async () => {
  const [signer] = await ethers.getSigners();
  const provider = signer.provider;

  if (!provider) {
    throw new Error("Provider is not available from Hardhat runtime");
  }

  const feeData = await provider.getFeeData();

  return {
    gasLimit: GAS_LIMIT,
    maxFeePerGas: MAX_FEE_PER_GAS,
    maxPriorityFeePerGas: PRIORITY_FEE,
  };
};

async function main() {
  const [deployer] = await ethers.getSigners();
  const ownerAddress = process.env.OWNER_ADDRESS;

  if (!ownerAddress) {
    throw new Error("OWNER_ADDRESS is not defined in the environment");
  }

  console.log("Deploying contracts with:", await deployer.getAddress());
  console.log("Network chainId:", (await deployer.provider!.getNetwork()).chainId.toString());

  const overrides = await getOverrides();

  const BancorFormula = await ethers.getContractFactory("BancorFormula");
  const bancorFormula = await BancorFormula.deploy(overrides);
  await bancorFormula.waitForDeployment();
  console.log("BancorFormula deployed at:", await bancorFormula.getAddress());

  const BondingCurve = await ethers.getContractFactory("BondingCurve");
  const bondingCurve = await BondingCurve.deploy(await bancorFormula.getAddress(), overrides);
  await bondingCurve.waitForDeployment();
  console.log("BondingCurve deployed at:", await bondingCurve.getAddress());

  const OwnerGroup = await ethers.getContractFactory("OwnerGroupContract");
  const ownerGroup = await OwnerGroup.deploy([ownerAddress], overrides);
  await ownerGroup.waitForDeployment();
  console.log("OwnerGroupContract deployed at:", await ownerGroup.getAddress());

  const TokenTreasury = await ethers.getContractFactory("TokenTreasury");
  const tokenTreasury = await TokenTreasury.deploy(ownerAddress, overrides);
  await tokenTreasury.waitForDeployment();
  console.log("TokenTreasury deployed at:", await tokenTreasury.getAddress());

  const TransactionHistory = await ethers.getContractFactory("TransactionHistory");
  const transactionHistory = await TransactionHistory.deploy(await deployer.getAddress(), overrides);
  await transactionHistory.waitForDeployment();
  console.log("TransactionHistory deployed at:", await transactionHistory.getAddress());

  const LaunchPadTokenFactory = await ethers.getContractFactory("LaunchPadTokenFactory");
  const tokenFactory = await LaunchPadTokenFactory.deploy(await deployer.getAddress(), overrides);
  await tokenFactory.waitForDeployment();
  console.log("LaunchPadTokenFactory deployed at:", await tokenFactory.getAddress());

  const LaunchPad = await ethers.getContractFactory("LaunchPad");
  const launchPad = await LaunchPad.deploy(
    await tokenTreasury.getAddress(),
    await bondingCurve.getAddress(),
    await ownerGroup.getAddress(),
    await transactionHistory.getAddress(),
    await tokenFactory.getAddress(),
    overrides,
  );
  await launchPad.waitForDeployment();
  console.log("LaunchPad deployed at:", await launchPad.getAddress());

  const ReferralTracker = await ethers.getContractFactory("ReferralTracker");
  const referralTracker = await ReferralTracker.deploy(await ownerGroup.getAddress(), overrides);
  await referralTracker.waitForDeployment();
  console.log("ReferralTracker deployed at:", await referralTracker.getAddress());

  const LaunchPadView = await ethers.getContractFactory("LaunchPadView");
  const launchPadView = await LaunchPadView.deploy();
  await launchPadView.waitForDeployment();
  console.log("LaunchPadView deployed at:", await launchPadView.getAddress());

  const launchPadAddress = await launchPad.getAddress();
  await (await transactionHistory.setLaunchPad(launchPadAddress, overrides)).wait();
  console.log("TransactionHistory linked to LaunchPad");
  await (await tokenFactory.setLaunchPad(launchPadAddress, overrides)).wait();
  console.log("LaunchPadTokenFactory linked to LaunchPad");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
