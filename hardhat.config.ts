import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

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
        }
      },
    ]
  },
  networks: {
    localhost: {
      initialBaseFeePerGas: 0,
    }
  }
};

export default config;
