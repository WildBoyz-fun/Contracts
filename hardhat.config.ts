import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.5.16",
        settings: {
          optimizer: { enabled: true, runs: 200 },
        }
      }, // for Uniswap v2-core
      {
        version: "0.6.6",
        settings: {
          optimizer: { enabled: true, runs: 200 },
        }
      },  // for Uniswap v2-periphery
      { version: "0.8.28", 
        settings: {
          optimizer: { enabled: true, runs: 200 },
          viaIR: true,
        }
      },
    ]
  },
  networks: {
    hardhat: {
      blockGasLimit: 100_000_000, // Maximum gas limit per block
//      gas: 10_000_000,            // Default gas limit per transaction
      allowUnlimitedContractSize: true, // Allow unlimited contract size
    },
    localhost: {
      initialBaseFeePerGas: 0,
    },
    monad_testnet: {
      url: process.env.MONAD_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    }
  }
};

export default config;
