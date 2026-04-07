# WildBoyz.fun Contracts

ERC-404 token launchpad smart contracts. Bonding curve trading with auto-graduation to Uniswap V2.

## Architecture

```
                        +-----------------+
                        |   OwnerGroup    |  (multi-sig access control)
                        +--------+--------+
                                 |
          +----------------------+----------------------+
          |                      |                      |
  +-------v--------+   +--------v--------+    +--------v--------+
  |   LaunchPad    |   | TokenFactory    |    | ReferralTracker |
  |  (UUPS Proxy)  |   | (UUPS Proxy)   |    | (UUPS Proxy)    |
  +-------+--------+   +--------+--------+    +-----------------+
          |                      |
          |              +-------v-------+
          |              | ERC404Token   |  (EIP-1167 Clones)
          |              +---------------+
          |
  +-------v-----------+    +---------------+
  | LiquidityProvider |    | BondingCurve  |  (stateless math)
  | (UUPS Proxy)      |    +---------------+
  +-------------------+
```

## Deployed Contracts (Base Sepolia, 2026-04-08)

### UUPS Upgradeable Proxies

Upgradeable while preserving all on-chain state (token registrations, balances, graduated pairs).

| Contract | Proxy Address | Description |
|---|---|---|
| **LaunchPad** | [`0x2E91Fb95897f4e40986CBb41Fb875261880BeB11`](https://sepolia.basescan.org/address/0x2E91Fb95897f4e40986CBb41Fb875261880BeB11) | Token creation, bonding curve buy/sell, auto-graduation |
| **TokenFactory** | [`0x53d3E83A2ecD420CddE0A99c70b3C9d9c18a4356`](https://sepolia.basescan.org/address/0x53d3E83A2ecD420CddE0A99c70b3C9d9c18a4356) | Creates ERC404Token clones (EIP-1167) |
| **LiquidityProvider** | [`0x0437A19E9bc535A05509B8EE2B98a97C53275669`](https://sepolia.basescan.org/address/0x0437A19E9bc535A05509B8EE2B98a97C53275669) | Uniswap V2 LP creation + permanent LP burn |
| **ReferralTracker** | [`0x61Ed63c9e09CbAa0Bb260b8beC59D4fbC408b06D`](https://sepolia.basescan.org/address/0x61Ed63c9e09CbAa0Bb260b8beC59D4fbC408b06D) | Points-based referral + ETH reward claims |

### Standard Contracts

| Contract | Address | Description |
|---|---|---|
| **ERC404Token** (impl) | [`0xBaf9D960B77FA14119982655CA57d20C4Ed4472e`](https://sepolia.basescan.org/address/0xBaf9D960B77FA14119982655CA57d20C4Ed4472e) | Clone template for new tokens |
| **BondingCurve** | [`0xaC61aBB70a6E54F4127bCa8A3FED9c0617E8E414`](https://sepolia.basescan.org/address/0xaC61aBB70a6E54F4127bCa8A3FED9c0617E8E414) | Bancor-style price curve |
| **OwnerGroup** | [`0x3FEf9A1812f14272dcf117EfF2fd363C86b3F5fA`](https://sepolia.basescan.org/address/0x3FEf9A1812f14272dcf117EfF2fd363C86b3F5fA) | Multi-owner access control |
| **TokenTreasury** | [`0xE3643e533933C335dce3c64B289b9cc6621999f0`](https://sepolia.basescan.org/address/0xE3643e533933C335dce3c64B289b9cc6621999f0) | Fee treasury (DAO governance) |
| **LaunchPadView** | [`0x0F349A827eD216321cFb68994FC1fAF7e36310fd`](https://sepolia.basescan.org/address/0x0F349A827eD216321cFb68994FC1fAF7e36310fd) | Read-only batch queries for frontend |

### Mock Uniswap V2 (Testnet)

| Contract | Address |
|---|---|
| MockWETH | `0x341e21260939c6d576d67B7109E5098c9B850B23` |
| MockFactory | `0xcA108dfD654b3Ae16c320bCbb8A78Ee42dc1aBA9` |
| MockRouter | `0x163f5e24b92dd352B59BE804dd6C280Eb486Fd57` |

### Config

| Parameter | Value |
|---|---|
| Chain | Base Sepolia (84532) |
| RPC | Alchemy |
| Owner | `0x51d36e1FaA913fbB8AD78c3e1B2e846cd9E9019b` |
| Graduation target | 1,000 tokens (testnet) |
| Fee rate | 1% |
| EVM target | Cancun |

## Token Lifecycle

1. **Create** - User calls `LaunchPad.createBioDiversityERC404Token()` -> TokenFactory creates EIP-1167 clone
2. **Trade** - Buy/sell via bonding curve (`buyToken` / `sellToken`)
3. **Graduate** - When `totalSupply >= targetFundRaisingAmount`, auto-graduates to Uniswap V2
4. **LP Lock** - LP tokens sent to `0x...dEaD` (permanent lock)

## Upgradeability (UUPS)

Proxy addresses are permanent. Only logic can be swapped.

```bash
# Upgrade LaunchPad
npx hardhat run scripts/upgrade-launchpad.ts --network base_sepolia
```

```typescript
import { ethers, upgrades } from "hardhat";

async function main() {
  const PROXY = "0x2E91Fb95897f4e40986CBb41Fb875261880BeB11";
  const V2 = await ethers.getContractFactory("LaunchPad");
  await upgrades.upgradeProxy(PROXY, V2, { kind: "uups" });
}
main().catch(console.error);
```

- Only `OwnerGroup` members can authorize upgrades
- `uint256[50] __gap` reserved for future storage
- `.openzeppelin/base-sepolia.json` tracks storage layout for validation

### Swap ERC404Token implementation

New tokens use the updated implementation. Existing clones keep their original.

```
tokenFactory.setImplementation(newImplAddress)
```

## Core Contracts

### LaunchPad.sol

| Function | Description |
|---|---|
| `createBioDiversityERC404Token()` | Create new ERC-404 token via factory |
| `buyToken(ca, minTokens)` | Buy tokens on bonding curve (slippage protected) |
| `sellToken(ca, amount, minEth)` | Sell tokens back (slippage protected) |
| `emergencyGraduate(ca)` | Force graduation (owner only) |
| `setTargetFundRaisingAmount(uint256)` | Change graduation target |
| `setFeeRate(uint8)` | Change fee 0-10% |

### BondingCurve.sol

Bancor formula. Reserve ratio 10%, supply/deposit offsets for stable initial pricing.

### ERC404Token.sol

ERC-404 (ERC-20 + ERC-721 hybrid). 24 decimals. 5 rarity tiers (39/23/20/12/6%). Clone-based with `initialize()`.

### ReferralTracker.sol

| Activity | Referrer | Referee |
|---|---|---|
| Account creation | +100 | +300 |
| Token buy | +1 | +10 |
| Token sell | 0 | -2 |

Owner funds reward pool with ETH. Users claim based on `points * ethPerPoint`.

## Development

```bash
npm install
npx hardhat compile
npx hardhat test          # 48 tests
```

## Deploy

```bash
# Set deployer key (once)
npx hardhat vars set DEPLOYER_PRIVATE_KEY

# Full deploy (Base Sepolia)
npx hardhat run scripts/deploy-base-sepolia.ts --network base_sepolia

# Deploy LaunchPadView only
npx hardhat run scripts/deploy-view.ts --network base_sepolia
```

## Tech Stack

- Solidity 0.8.28 + viaIR + Cancun EVM
- OpenZeppelin Contracts v5.3.0 + Upgradeable
- Hardhat + hardhat-upgrades (UUPS)
- ERC-404 (ERC404U16)
- Uniswap V2

## Tests (48 passing)

```
BondingCurve (3)           - Purchase ordering, sell return, max limit
ERC404Token (7)            - Init, ERC20/721, tax, metadata, access
LaunchPad (10)             - Deploy, status, buy, sell, calculation
LaunchPad Auto LP (4)      - Auto graduation, emergency, multi-token
LaunchPadTokenTreasury (1) - ETH deposit/withdraw
LiquidityProvider (3)      - LP + burn, auth, slippage
OwnerGroup (8)             - Multi-owner CRUD
Referral Integration (4)   - Buy/sell points, no-tracker safety
Referral Claim (5)         - Fund, claim, epoch, reject
TokenTreasury (3)          - DAO access control
```
