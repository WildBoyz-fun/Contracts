# Latest contract deployment information

BondingCurveModule#BondingCurve - 0x0aad72C69684f8030ccd39a598f038fAeAFF3A14
OwnerGroupModule#OwnerGroupContract - 0xFe692cf3EDad569e112c13f2e86A2050b8327212
TokenTreasuryModule#TokenTreasury - 0x867420aeb117db267ebfd167a501fdAb301d7Ac8
LaunchPadModule#LaunchPad - 0x990bC0A0404eC8d000709940439F6f019c35A0ba
LiquidityProviderModule#LiquidityProvider - 0x92B99862fF958ff2707201977073fe03B0A888c1

**TBD:** [Contract Address](https://testnet.blastscan.io/address/0xd1656cd192ab0a3d094CC7338e6852CC84d27249),	latest (04.24)

# Dev Env configuration

> brew install node

> nvm install v20.12.2 

> npm install @openzeppelin/contracts

> npm hardhat install

> npm install dotenv

> npm install --save-dev @nomicfoundation/hardhat-verify 



# DEPLOYMENT, VERIFICATION (Using HardHat) ==> 메인넷 정하면... 다시 업데이트
**Compile:** 
> npx hardhat compile  

**Deploy (Monad_Testnet):** 
> npx hardhat ignition deploy ignition/modules/DeployContracts.ts --network monad_testnet

**Deploy (Blast_Sepolia):** 
> npx hardhat ignition deploy ignition/modules/ReferralThrones.js --network blast_sepolia

**Deploy (Blast_Mainnet):** 
> npx hardhat ignition deploy ignition/modules/ReferralThrones.js --network blast_mainnet  

**Verify all contracts (Blast_Sepolia):** 
> chmod +x execVerifyAll.js
> 
> execVerifyAll.js testnet

**Verify all contracts (Blast_Mainnet):** 
> chmod +x execVerifyAll.js
> 
> execVerifyAll.js mainnet

**Verify individual contract (Blast_Sepolia):** 
> npx hardhat verify --network blast_sepolia [deployed contract address] --constructor-args ./verification-arguments/CONTRACT_FILE_NAME-args.js

**Verify individual contract (Blast_Sepolia):** 
> npx hardhat verify --network blast_mainnet [deployed contract address] --constructor-args ./verification-arguments/CONTRACT_FILE_NAME-args.js


# TEST (Using HardHat)
> npx hardhat test --network blast_sepolia

## Test LiquidityProvider

https://blog.uniswap.org/your-first-uniswap-integration
1. Create an app in https://dashboard.alchemy.com/ with enabling ethereum mainnet network.
2. Fork ethereum mainnet locally
> npx hardhat node --fork https://eth-mainnet.alchemyapi.io/v2/{YOUR_API_KEY}
3. Test with local network
> npx hardhat test test/LiquidityProvider.test.ts --network localhost

# .env
환경변수..




