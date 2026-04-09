import { HardhatUserConfig, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";

// ============================================================
// KEY MANAGEMENT: Private key is stored in Hardhat's encrypted keystore.
//
// First-time setup:
//   npx hardhat vars set DEPLOYER_PRIVATE_KEY
//   (will prompt for the key — never stored in plaintext on disk)
//
// Optional: set per-chain RPC URLs
//   npx hardhat vars set BASE_SEPOLIA_RPC_URL
//   npx hardhat vars set UNI_ROUTER_ADDRESS
//
// View stored vars:
//   npx hardhat vars list
//
// Where are they stored?
//   npx hardhat vars path
//   → encrypted file in ~/.config/hardhat-nodejs/
// ============================================================

// Private key from keystore (no .env needed for keys)
const DEPLOYER_KEY = vars.has("DEPLOYER_PRIVATE_KEY")
  ? [vars.get("DEPLOYER_PRIVATE_KEY")]
  : [];

// RPC URLs — keystore or fallback to defaults
const BASE_SEPOLIA_RPC = vars.has("BASE_SEPOLIA_RPC_URL")
  ? vars.get("BASE_SEPOLIA_RPC_URL")
  : "https://sepolia.base.org";

const BASE_MAINNET_RPC = vars.has("BASE_MAINNET_RPC_URL")
  ? vars.get("BASE_MAINNET_RPC_URL")
  : "https://mainnet.base.org";

const ETH_SEPOLIA_RPC = vars.has("ETH_SEPOLIA_RPC_URL")
  ? vars.get("ETH_SEPOLIA_RPC_URL")
  : "";

const MONAD_RPC = vars.has("MONAD_RPC_URL")
  ? vars.get("MONAD_RPC_URL")
  : "";

// Uniswap Router address (for DeployContract.ts)
// Set with: npx hardhat vars set UNI_ROUTER_ADDRESS
const UNI_ROUTER = vars.has("UNI_ROUTER_ADDRESS")
  ? vars.get("UNI_ROUTER_ADDRESS")
  : "";

// Export for use in deployment scripts
export { UNI_ROUTER };

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.5.16",
        settings: { optimizer: { enabled: true, runs: 200 } },
      },
      {
        version: "0.6.6",
        settings: { optimizer: { enabled: true, runs: 200 } },
      },
      {
        version: "0.8.28",
        settings: {
          viaIR: true,
          evmVersion: "cancun",
          optimizer: { enabled: true, runs: 200 },
        },
      },
    ],
  },
  networks: {
    // Local development
    hardhat: {
      blockGasLimit: 100_000_000,
      allowUnlimitedContractSize: true,
    },
    localhost: {
      initialBaseFeePerGas: 0,
    },

    // ===== Testnets =====
    base_sepolia: {
      url: BASE_SEPOLIA_RPC,
      chainId: 84532,
      accounts: DEPLOYER_KEY,
    },
    ethereum_sepolia: {
      url: ETH_SEPOLIA_RPC,
      chainId: 11155111,
      accounts: DEPLOYER_KEY,
    },
    monad_testnet: {
      url: MONAD_RPC,
      chainId: 10143,
      accounts: DEPLOYER_KEY,
    },

    // ===== Mainnets =====
    base_mainnet: {
      url: BASE_MAINNET_RPC,
      chainId: 8453,
      accounts: DEPLOYER_KEY,
    },
  },
  etherscan: {
    apiKey: vars.has("BASESCAN_API_KEY") ? vars.get("BASESCAN_API_KEY") : "",
  },
};

export default config;
