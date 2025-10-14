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

# Hyperliquid (HyperEVM) deployment notes

- HyperEVM 기본 블록은 Small Block(가스 한도 2,000,000)이라 복잡한 컨트랙트 배포가 실패할 수 있습니다.
- `HYPERLIQUID_PRIVATE_KEY` (또는 `PRIVATE_KEY`) 환경 변수를 설정한 뒤 아래 스크립트로 Big Block 모드로 전환하세요:

```bash
npm run hyperliquid:block:big
```

- 배포를 마쳤다면 필요에 따라 Small Block 모드로 복구할 수 있습니다:

```bash
npm run hyperliquid:block:small
```

- Big Block 전환은 LayerZero CLI(`@layerzerolabs/hyperliquid-composer`)를 사용하며, 내부적으로 Hyperliquid 메인넷에 트랜잭션을 전송합니다. 실행 전에 메인넷 계정과 서명 키가 준비돼 있어야 합니다.
- 블록 전환 후에는 Hardhat/Foundry 배포를 실행하면 됩니다. 검증은 https://testnet.purrsec.com/verify 를 참고하세요.


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




