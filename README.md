# WildBoyz.fun Contracts

ERC-404 token launchpad smart contracts. Bonding curve trading with auto-graduation to Uniswap V2.

## Architecture

```
                        +-------------------+
                        |   OwnerGroup      |  (multisig access control)
                        | proposal → confirm |
                        |   → execute       |
                        +--------+----------+
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

## Deployed Contracts (Base Sepolia, 2026-04-10)

### UUPS Upgradeable Proxies

Upgradeable while preserving all on-chain state (token registrations, balances, graduated pairs).

| Contract | Proxy Address | Description |
|---|---|---|
| **LaunchPad** | `0x4844874dDeC2C0b5040130515b8aA91861483aA8` | Token creation, bonding curve buy/sell, auto-graduation, pause |
| **TokenFactory** | `0x7F2ABF905E78c50774d458271Ad18810a06F57a3` | Creates ERC404Token clones (EIP-1167) |
| **LiquidityProvider** | `0x953cb16A86c775D0F9662316F066B6271C5A4f14` | Uniswap V2 LP creation + permanent LP burn |
| **ReferralTracker** | `0x5f04FEc5493DE9A11229559854492a8Cea7950dE` | Points-based referral + ETH reward claims |

### Standard Contracts

| Contract | Address | Description |
|---|---|---|
| **ERC404Token** (impl) | `0x557189672a359aEF796fDEc20D8821d0e9070faa` | Clone template (uint16 overflow fix) |
| **BondingCurve** | Deployed with initial setup | Bancor-style price curve |
| **OwnerGroup** | `0x1451dddF926BfD6556a5E5989Ed3A3c3620A058D` | **Multisig** access control with proposal system |
| **TokenTreasury** | Deployed with initial setup | Fee treasury (DAO governance) |

### Mock Uniswap V2 (Testnet Only)

| Contract | Address |
|---|---|
| MockWETH | `0x8c1db1A2A4534C742E8881699fb838027EAC97E5` |
| MockFactory | `0x5e8436801d78251e061Df4CDbC714CF68fCDA513` |
| MockRouter | `0x60EF1BA1e32296f596ef0472e115DF548B04Dcf8` |

### Config

| Parameter | Value |
|---|---|
| Chain | Base Sepolia (84532) |
| RPC | Alchemy |
| Owner | `0x51d36e1FaA913fbB8AD78c3e1B2e846cd9E9019b` |
| Graduation target | 10 ETH (configurable) |
| Fee rate | 1% |
| EVM target | Cancun |

## Token Lifecycle

1. **Create** - User calls `LaunchPad.createBioDiversityERC404Token()` -> TokenFactory creates EIP-1167 clone
2. **Trade** - Buy/sell via bonding curve (`buyToken` / `sellToken`)
3. **Graduate** - When `ethDepositBalance >= targetEthAmount`, auto-graduates to Uniswap V2
4. **LP Lock** - LP tokens sent to `0x...dEaD` (permanent lock)
5. **DEX Trade** - After graduation, tokens trade on Uniswap V2 via Swap UI

## Multisig Proposal System

Emergency withdrawals and critical operations require majority approval when 3+ owners exist.

### How It Works

| Owner Count | Required Confirmations |
|---|---|
| 1 | 1 (auto-execute) |
| 2 | 1 (auto-execute) |
| 3 | 2 (majority) |
| 4 | 3 (majority) |
| 5 | 3 (majority) |

### Usage: Emergency Withdraw via Multisig

```solidity
// Step 1: Owner A submits proposal (gets 1 confirmation automatically)
// Encode the target function call
bytes memory data = abi.encodeWithSignature("emergencyWithdrawETH(uint256)", 1 ether);
uint256 proposalId = ownerGroup.submitProposal(launchPadAddress, data, 0);

// Step 2: Owner B confirms (reaches majority -> auto-executes)
ownerGroup.confirmProposal(proposalId);

// If not enough confirmations yet, Owner C also confirms
ownerGroup.confirmProposal(proposalId);
```

### View Proposals

```solidity
// Get all pending proposals
uint256[] memory pending = ownerGroup.getPendingProposals();

// Get proposal details
(address target, bytes memory data, uint256 value,
 uint256 confirmCount, bool executed, uint256 createdAt) = ownerGroup.getProposal(proposalId);

// Check if specific owner confirmed
bool confirmed = ownerGroup.hasConfirmed(proposalId, ownerAddress);
```

### Revoke Confirmation

```solidity
ownerGroup.revokeConfirmation(proposalId);
```

Proposals expire after **7 days** if not executed.

## Emergency Withdraw Functions

Every contract that holds ETH or tokens has emergency withdrawal capability.

| Contract | Function | Access |
|---|---|---|
| **LaunchPad** | `emergencyWithdrawETH(amount)` | onlyOwnerGroup -> treasury |
| **LaunchPad** | `emergencyWithdrawToken(token, amount)` | onlyOwnerGroup -> treasury |
| **LiquidityProvider** | `emergencyWithdrawETH(to, amount)` | onlyOwnerGroup |
| **LiquidityProvider** | `emergencyWithdrawToken(token, to, amount)` | onlyOwnerGroup |
| **ReferralTracker** | `emergencyWithdrawETH(to, amount)` | onlyOwner |
| **MockRouter** | `emergencyWithdrawETH(to)` | onlyOwner (deployer) |
| **MockRouter** | `emergencyWithdrawToken(token, to)` | onlyOwner (deployer) |

When ownerCount >= 3, these calls must go through the **multisig proposal system**.

## Pause Mechanism

LaunchPad has an emergency pause that blocks `buyToken`, `sellToken`, and `createToken`.

```solidity
launchPad.pause();   // Emergency stop
launchPad.unpause(); // Resume
```

## Core Contracts

### LaunchPad.sol

| Function | Description |
|---|---|
| `createBioDiversityERC404Token()` | Create new ERC-404 token via factory |
| `buyToken(ca, minTokens)` | Buy tokens on bonding curve (slippage protected) |
| `sellToken(ca, amount, minEth)` | Sell tokens back (slippage protected) |
| `emergencyGraduate(ca)` | Force graduation (owner only) |
| `setTargetEthAmount(uint256)` | Change ETH graduation target |
| `setFeeRate(uint8)` | Change fee 0-10% |
| `pause() / unpause()` | Emergency circuit breaker |
| `emergencyWithdrawETH/Token()` | Rescue stuck funds |
| `sweepDust(startIndex, batchSize)` | Recover rounding dust (paginated) |
| `setOwnerGroup(address)` | Migrate to new OwnerGroup |

### BondingCurve.sol

Bancor formula. Reserve ratio 10%, supply/deposit offsets for stable initial pricing.

### ERC404Token.sol

ERC-404 (ERC-20 + ERC-721 hybrid). 24 decimals. 5 rarity tiers (39/23/20/12/6%). Clone-based with `initialize()`. Max 65,535 unique NFT IDs (uint16 safety check).

### ReferralTracker.sol

| Activity | Referrer | Referee |
|---|---|---|
| Account creation | +100 | +300 |
| Token buy | +1 | +10 |
| Token sell | 0 | -2 |

Points capped at 1 billion (overflow protection). Owner funds reward pool with ETH. Users claim based on `points * ethPerPoint`. Reentrancy guard on `claimReward`.

### LiquidityProvider.sol

Handles Uniswap V2 LP creation during graduation. LP tokens are burned to `0x...dEaD` for permanent liquidity. Router/Factory/WETH are configurable via `setRouter()`.

## Security Features

| Feature | Description |
|---|---|
| **Multisig proposals** | Majority confirmation required for owner actions (3+ owners) |
| **Reentrancy guards** | On all state-changing ETH transfer functions |
| **Emergency pause** | Circuit breaker for trading and token creation |
| **Emergency withdrawals** | Every fund-holding contract has rescue functions |
| **ERC721 exempt presets** | Router, pair, LP provider all exempted before graduation |
| **Overflow protection** | int256 bounds on referral points, uint16 check on NFT IDs |
| **Slippage protection** | `minTokens` / `minEth` on buy/sell |
| **Excess refund** | Over-purchase refunded when hitting graduation cap |
| **LP permanent burn** | LP tokens sent to dead address |
| **CEI pattern** | Checks-Effects-Interactions on all fund transfers |
| **Proposal expiry** | Multisig proposals expire after 7 days |

## Upgradeability (UUPS)

Proxy addresses are permanent. Only logic can be swapped.

```bash
npx hardhat run scripts/upgrade-security.ts --network base_sepolia
```

- Only `OwnerGroup` members can authorize upgrades
- `uint256[48-50] __gap` reserved for future storage
- `.openzeppelin/base-sepolia.json` tracks storage layout for validation

### Swap ERC404Token implementation

New tokens use the updated implementation. Existing clones keep their original.

```
tokenFactory.setImplementation(newImplAddress)
```

## Development

```bash
npm install
npx hardhat compile
npx hardhat test          # 57 tests
```

## Deploy

```bash
# Set deployer key (once)
npx hardhat vars set DEPLOYER_PRIVATE_KEY

# Full deploy (Base Sepolia)
npx hardhat run scripts/deploy-base-sepolia.ts --network base_sepolia
```

## Tests (57 passing)

```
BondingCurve (3)           - Purchase ordering, sell return, max limit
ERC404Token (7)            - Init, ERC20/721, tax, metadata, access
LaunchPad (10)             - Deploy, status, buy, sell, calculation
LaunchPad Auto LP (4)      - Auto graduation, emergency, multi-token
LaunchPadTokenTreasury (1) - ETH deposit/withdraw
LiquidityProvider (3)      - LP + burn, auth, slippage
OwnerGroup (8)             - Multi-owner CRUD
MultisigProposal (9)       - Majority confirm, auto-execute, revoke, expiry
Referral Integration (4)   - Buy/sell points, no-tracker safety
Referral Claim (5)         - Fund, claim, epoch, reject
TokenTreasury (3)          - DAO access control
```

## Mainnet Deployment Checklist

- [ ] Replace MockRouter/Factory/WETH with real Uniswap V2 addresses
- [ ] Set production graduation target (`setTargetEthAmount`)
- [ ] Add all team wallets to OwnerGroup (3+ for multisig)
- [ ] Verify all contracts on BaseScan
- [ ] Test emergency withdraw flow with multisig
- [ ] Set appropriate `maxGasPrice` for anti-bot
