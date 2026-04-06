# oops4.fun - ERC-404 LaunchPad Smart Contracts

ERC-404 기반 토큰 런치패드. 본딩 커브를 통한 토큰 판매 → 졸업 조건 달성 시 자동으로 Uniswap V2 DEX 풀 생성 및 유동성 영구 잠금.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                        LaunchPad.sol                          │
│  - 토큰 생성 (via TokenFactory)                               │
│  - 본딩 커브 Buy / Sell                                       │
│  - 졸업 시 자동 LP 생성 (_graduateToken)                       │
│  - 긴급 졸업 (emergencyGraduate)                              │
│  - 졸업 목표/수수료율 설정 (Admin)                              │
└────────┬──────────┬──────────────┬────────────────────────────┘
         │          │              │
         ▼          ▼              ▼
┌──────────────┐ ┌────────────────────────┐ ┌──────────────────┐
│ BondingCurve │ │   LiquidityProvider    │ │  TokenFactory    │
│ Bancor 공식   │ │ - Uniswap V2 LP 추가   │ │ - ERC404 토큰    │
│ 가격 산출     │ │ - LP 토큰 burn (잠금)   │ │   생성 (분리)    │
│              │ │ - 슬리피지 보호 (5%)    │ │                  │
└──────────────┘ └────────────────────────┘ └──────────────────┘
         │
         ▼
┌────────────────────────────────────────────────┐
│              ERC404Token.sol                     │
│  ERC-20 + ERC-721 하이브리드 토큰 (ERC404U16)    │
│  - 정수 단위 보유 시 NFT 자동 민팅               │
│  - 레어리티 기반 프로시저럴 메타데이터             │
│  - 전송 시 세금 (taxPermil)                      │
└────────────────────────────────────────────────┘
```

---

## Live Deployment (Base Sepolia Testnet)

> Deployed: 2026-04-06 | Chain ID: 84532 | Explorer: https://sepolia.basescan.org

| Contract | Address |
|----------|---------|
| **LaunchPad** | [`0xD839bEfd540515b82C75873ab40cD8202367ae3F`](https://sepolia.basescan.org/address/0xD839bEfd540515b82C75873ab40cD8202367ae3F) |
| **TokenFactory** | [`0x795F70f8099DaA84C25e36C7e7dc18f803A70548`](https://sepolia.basescan.org/address/0x795F70f8099DaA84C25e36C7e7dc18f803A70548) |
| **LiquidityProvider** | [`0x8776d2C4E860Eb30763f53F2976cBEd7797c9b7b`](https://sepolia.basescan.org/address/0x8776d2C4E860Eb30763f53F2976cBEd7797c9b7b) |
| **ReferralTracker** | [`0xCDBB7714b0B5664B7715C076929b7492D9B39b30`](https://sepolia.basescan.org/address/0xCDBB7714b0B5664B7715C076929b7492D9B39b30) |
| **BondingCurve** | [`0x7dD459B9287315a11063f73715d95fd2C27296D5`](https://sepolia.basescan.org/address/0x7dD459B9287315a11063f73715d95fd2C27296D5) |
| **OwnerGroup** | [`0x38cA31C5805fB55a7A699859Db32DF73929fDA21`](https://sepolia.basescan.org/address/0x38cA31C5805fB55a7A699859Db32DF73929fDA21) |
| **TokenTreasury** | [`0xAe903b461B280400C7cac01a8911DC83a1e17c57`](https://sepolia.basescan.org/address/0xAe903b461B280400C7cac01a8911DC83a1e17c57) |
| UniswapV2 Router | [`0x23a2Ef780C23da0346e3C0FeCa09249F8E9681A5`](https://sepolia.basescan.org/address/0x23a2Ef780C23da0346e3C0FeCa09249F8E9681A5) |
| UniswapV2 Factory | [`0xB4BAcA200dA1F9ede8E909C2aC8565e3AA63BB25`](https://sepolia.basescan.org/address/0xB4BAcA200dA1F9ede8E909C2aC8565e3AA63BB25) |
| WETH | [`0xd683373356FC23181a4F6d632F1558266B0157DB`](https://sepolia.basescan.org/address/0xd683373356FC23181a4F6d632F1558266B0157DB) |

**Testnet Config:**
- Deployer / Owner: `0x51d36e1FaA913fbB8AD78c3e1B2e846cd9E9019b`
- Graduation target: **1,000 tokens** (테스트용, Admin에서 변경 가능)
- Fee rate: 1%

### Previous Deployments

<details>
<summary>Monad Testnet (deprecated)</summary>

| Contract | Address |
|----------|---------|
| BondingCurve | `0x0aad72C69684f8030ccd39a598f038fAeAFF3A14` |
| OwnerGroupContract | `0xFe692cf3EDad569e112c13f2e86A2050b8327212` |
| TokenTreasury | `0x867420aeb117db267ebfd167a501fdAb301d7Ac8` |
| LaunchPad | `0x990bC0A0404eC8d000709940439F6f019c35A0ba` |
| LiquidityProvider | `0x92B99862fF958ff2707201977073fe03B0A888c1` |

</details>

---

## Core Contracts

### LaunchPad.sol
메인 컨트랙트. 토큰 생성, 본딩 커브 거래, 졸업 처리를 담당.

| 함수 | 설명 |
|------|------|
| `createBioDiversityERC404Token()` | 새 ERC-404 토큰 생성 (via TokenFactory) |
| `buyToken(address)` | 본딩 커브로 토큰 구매. 수수료 차감. 목표 달성 시 자동 졸업 |
| `sellToken(address, amount)` | 본딩 커브로 토큰 판매. 졸업 전에만 가능 |
| `emergencyGraduate(address)` | Owner 전용. 목표 미달성 시에도 강제 졸업 |
| `setTargetFundRaisingAmount(uint256)` | 졸업 목표 토큰 수량 변경 (Owner) |
| `setFeeRate(uint8)` | 수수료율 변경 0~10% (Owner) |
| `getContractGraduationStatus(address)` | 졸업 여부 조회 |
| `getGraduatedPair(address)` | 졸업된 토큰의 Uniswap pair 주소 조회 |
| `setReferralTrackerContract(address)` | ReferralTracker 연결 (Owner) |
| `sendEthToTreasury(amount)` | 누적 수수료를 Treasury로 출금 |

**졸업 흐름 (자동):**
1. `buyToken()` → `totalSupply >= targetFundRasingAmount` 도달
2. `_graduateToken()` 실행:
   - `saleIsActive = false`, `isGraduated = true`
   - LiquidityProvider에 ERC721 면제 설정 (가스 최적화)
   - 잔여 토큰 + 누적 ETH → LiquidityProvider로 전송
   - Uniswap V2 풀 생성 → LP 토큰 burn (0xdead)
   - DEX pair에 ERC721 면제 설정
   - `Graduated` 이벤트 발행

### TokenFactory.sol
ERC404Token 생성을 LaunchPad에서 분리. 컨트랙트 크기 24KB 제한 준수.

### LiquidityProvider.sol
Uniswap V2 유동성 추가 및 LP 토큰 영구 잠금 담당.

| 함수 | 설명 |
|------|------|
| `addLiquidityETH(token, tokenAmount, ethAmount)` | 유동성 추가 + LP 토큰 burn |
| `setSlippageTolerance(uint256)` | 슬리피지 허용치 변경 (80-100%, 기본 95%) |
| `isGraduated(address)` | 토큰 졸업 여부 조회 |
| `getGraduationInfo(address)` | 졸업 상세 정보 (pair, 수량, LP burn량, 시간) |
| `getGraduatedTokens()` | 전체 졸업 토큰 목록 |

### BondingCurve.sol
Bancor 공식 기반 연속 가격 산출.

| 파라미터 | 값 | 설명 |
|----------|-----|------|
| Reserve Ratio | 10% (100,000) | ETH 대비 토큰 담보율 |
| Token Supply Offset | ~1.76 × 10^27 | 초기 가격 안정화 |
| Deposit Balance Offset | 0.97 ETH | 0 나누기 방지 |

### ERC404Token.sol
ERC-404 (ERC-20 + ERC-721 하이브리드) 토큰. ERC404U16 기반 (최대 65,535 NFT).

- **Decimals**: 24
- 정수 단위(10^24) 보유 시 NFT 자동 민팅/소각
- 레어리티 5단계: seed 기반 확률 분배 (39% / 23% / 20% / 12% / 6%)
- 전송 시 세금: `taxPermil / 1000` 비율로 TokenTreasury에 차감

### ReferralTracker.sol
레퍼럴 포인트 시스템 + 보상 클레임.

| 함수 | 설명 |
|------|------|
| `registerWithReferral(referrer)` | 추천인 등록 (1회). 계정 생성 보상 자동 기록 |
| `recordReferral(activityType, user)` | 활동별 포인트 적립 (authorized contracts만) |
| `fundRewardPool(ethPerPoint)` | Owner가 보상 풀 ETH 입금 + 포인트당 ETH 설정 |
| `claimReward()` | 사용자 보상 클레임 (포인트 × ethPerPoint) |
| `getClaimableReward(user)` | 클레임 가능 금액 조회 |

**기본 포인트 설정:**

| 활동 | 추천인 보상 | 피추천인 보상 |
|------|------------|-------------|
| 계정 생성 | +100 | +300 |
| 토큰 구매 | +1 | +10 |
| 토큰 판매 | 0 | -2 |

### OwnerGroupContract.sol
다중 Owner 관리. Owner 추가/제거, 목록 조회.

| 함수 | 설명 |
|------|------|
| `getOwners()` | 전체 Owner 주소 목록 반환 |
| `registerOwner(address)` | Owner 추가 (기존 Owner만) |
| `unRegisterOwner(address)` | Owner 제거 (자기 자신 제거 불가, 최소 1명 보장) |

### TokenTreasury.sol
DAO 거버넌스. ERC-404 토큰 홀더가 제안 생성/투표, Owner가 실행.

### 보조 Contracts

| Contract | 설명 |
|----------|------|
| `LaunchPadTokenTreasury.sol` | LaunchPad 수수료 보관 및 출금 |
| `MaxGasPrice.sol` | 프론트러닝 방지 (가스 가격 상한) |
| `MockUniswap.sol` | 테스트/배포용 Uniswap V2 (Factory, Router, WETH, LP Token) |

---

## Key Parameters

| 파라미터 | 기본값 | 변경 가능 | 위치 |
|----------|--------|-----------|------|
| 졸업 목표 | 800,000,000 tokens | `setTargetFundRaisingAmount()` | LaunchPad |
| Max Supply | 1,000,000,000 tokens | 토큰 생성 시 | ERC404Token |
| Buy/Sell 수수료 | 1% | `setFeeRate()` | LaunchPad |
| 슬리피지 허용치 | 5% (95% min) | `setSlippageTolerance()` | LiquidityProvider |
| LP 토큰 | burn (0xdead) | 변경 불가 | 영구 잠금 |

---

## Events

```solidity
event TokenPurchased(address indexed tokenAddress, address indexed buyer, uint256 amount, uint256 price);
event TokenSold(address indexed tokenAddress, address indexed seller, uint256 amount, uint256 price);
event ContractDeployed(address indexed contractAddress, address indexed deployedBy, string symbolName);
event SaleEnded(address contractAddress, uint256 contractTotalSupply, uint256 targetFundRasingAmount);
event SuppliedLP(address indexed contractAddress, uint256 tokenAmount, uint256 ethAmount);
event Graduated(address indexed tokenAddress, address indexed pairAddress, uint256 tokenAmount, uint256 ethAmount, uint256 lpTokensBurned);
event EmergencyGraduated(address indexed tokenAddress, address indexed triggeredBy);
event LPTokensBurned(address indexed token, address indexed pair, uint256 amount);
event RewardClaimed(address indexed user, uint256 amount, int256 points, uint256 epoch);
```

---

## Multi-Chain Support

체인 설정은 한 곳에서 관리. EVM 호환 체인 추가/삭제가 간편.

**Contracts** (`hardhat.config.ts`):
- `NETWORKS` 객체에 체인 추가 → `npx hardhat vars set` 으로 RPC/키 설정

**Frontend** (`src/lib/chains.ts`):
- 체인 정의 추가 → `SUPPORTED_CHAINS` 등록 → `.env`에 `NEXT_PUBLIC_CHAIN_ID` 변경

| 체인 | Chain ID | 상태 |
|------|----------|------|
| Base Sepolia | 84532 | **Active (testnet)** |
| Base Mainnet | 8453 | 준비됨 |
| Ethereum Sepolia | 11155111 | 설정됨 |
| Hardhat Local | 31337 | 개발용 |

---

## Key Management

Private key는 **Hardhat 암호화 keystore**에 저장. `.env`에 평문 키 없음.

```bash
# 키 저장 (1회)
npx hardhat vars set DEPLOYER_PRIVATE_KEY
npx hardhat vars set OWNER_ADDRESS

# 확인
npx hardhat vars list
npx hardhat vars path    # ~/.config/hardhat-nodejs/vars.json
```

---

## Dev Setup

```bash
# Node.js (v20+)
nvm install v20.12.2

# Dependencies
npm install

# Compile
npx hardhat compile

# Test (48개 전체)
npx hardhat test
```

## Deployment

```bash
# 1. 키 설정 (최초 1회)
npx hardhat vars set DEPLOYER_PRIVATE_KEY    # 0x...
npx hardhat vars set OWNER_ADDRESS           # 0x...

# 2-A. Base Sepolia 전체 배포 (Uniswap V2 포함)
npx hardhat run scripts/deploy-base-sepolia.ts --network base_sepolia

# 2-B. 기존 Uniswap V2가 있는 체인에 배포
npx hardhat vars set UNI_ROUTER_ADDRESS      # 기존 Router 주소
npx hardhat ignition deploy ignition/modules/DeployContract.ts --network base_sepolia

# 2-C. 로컬 개발
npx hardhat ignition deploy ignition/modules/LocalDev.ts
```

---

## File Structure

```
contracts/
├── LaunchPad.sol              # 메인 런치패드 (Buy/Sell, 졸업, Admin)
├── TokenFactory.sol           # ERC404 토큰 생성 (LaunchPad에서 분리)
├── LiquidityProvider.sol      # Uniswap V2 LP 생성 + LP burn
├── BondingCurve.sol           # Bancor 본딩 커브
├── ERC404Token.sol            # ERC-404 토큰 (ERC-20 + ERC-721)
├── ReferralTracker.sol        # 레퍼럴 + 보상 클레임
├── TokenTreasury.sol          # DAO 거버넌스
├── LaunchPadTokenTreasury.sol # 수수료 관리
├── OwnerGroupContract.sol     # 다중 Owner (추가/제거/목록)
├── libs/
│   ├── ERC404/                # ERC404U16, IERC404, Queue
│   ├── BancorFormula.sol
│   ├── Power.sol
│   ├── MaxGasPrice.sol
│   ├── IOwnerGroupContract.sol
│   └── IReferralTracker.sol
├── mocks/
│   ├── MockUniswap.sol        # Factory, Router, WETH, LP Token
│   └── MockERC20.sol
scripts/
│   └── deploy-base-sepolia.ts # Base Sepolia 전체 배포 스크립트
test/
├── LaunchPadAutoLP.test.ts    # 졸업 + LP 생성
├── LaunchPad.test.ts          # Buy/Sell 기본
├── LiquidityProvider.test.ts  # LP 단독
├── ReferralIntegration.test.ts # Referral + LaunchPad 통합
├── ReferralClaim.test.ts      # 보상 클레임
├── TokenTreasury.test.ts      # DAO Treasury 접근 제어
├── OwnerGroup.test.ts         # 다중 Owner 관리
├── BondingCurve.test.ts
├── ERC404Token.test.ts
└── LaunchPadTokenTreasury.test.ts
ignition/modules/
├── FullDeploy.ts              # 전체 배포 (Uniswap V2 포함, 테스트넷용)
├── DeployContract.ts          # 프로덕션 배포 (기존 DEX 사용)
├── UniswapV2.ts               # Uniswap V2만 별도 배포
├── LocalDev.ts                # 로컬 개발 전체 배포
├── OwnerGroup.ts
├── TokenTreasury.ts
├── BondingCurve.ts
├── LiquidityProvider.ts
└── LaunchPad.ts
```

---

## Test Results (48 passing)

```
BondingCurve (3)              ✔ 초기 구매자 유리 / 매도 환불 / 최대 한도
ERC404Token (7)               ✔ 초기화 / ERC20-721 전환 / 세금 / 메타데이터 / 접근제어
LaunchPad (10)                ✔ 배포 / 상태 / Buy / Sell / 수량 계산
LaunchPad Auto LP (4)         ✔ 자동 졸업 / 긴급 졸업 / 다중 토큰 / 졸업 상태
LaunchPadTokenTreasury (1)    ✔ ETH 입출금
LiquidityProvider (3)         ✔ LP 생성+burn / 접근 제어 / 슬리피지 설정
OwnerGroup (8)                ✔ 멀티 Owner / 추가 / 제거 / 자기 삭제 방지 / 목록 일관성
Referral Integration (4)      ✔ Buy 포인트 / Sell 포인트 / 미설정 시 안전 / 추천인 없을 때
Referral Claim (5)            ✔ 풀 펀딩 / 클레임 / 에포크 반복 / 0포인트 거부 / 권한
TokenTreasury Access (3)      ✔ 실행 권한 제한 / 등록 권한 제한 / 정상 실행
```

---

## Frontend

- **Admin 페이지** (`/admin`): 졸업 목표 설정, 수수료 관리, Owner 관리, 토큰 목록, 긴급 졸업, 레퍼럴 풀 펀딩
- **졸업 후 UI**: "Trade on DEX" 버튼 + pair 주소 표시
- **차트**: Supabase 기반 거래 데이터 (TransactionBot 연동)
- **트렌딩**: 24시간 거래량 기준 정렬
- **레퍼럴 클레임**: 포인트 기반 ETH 보상 수령 UI

## Backend API

| Endpoint | Method | 설명 |
|----------|--------|------|
| `/auth/web3` | POST | Web3 서명 → Firebase 토큰 |
| `/tokens/:address/status` | GET | 토큰 상태 (on-chain) |
| `/tokens/:address/graduation` | GET | 졸업 상세 정보 |
| `/tokens/graduated` | GET | 졸업 토큰 목록 |
| `/tokens/launched` | GET | 전체 토큰 목록 |
| `/contracts` | POST | 사용자 컨트랙트 저장 |
| `/contracts/:wallet` | GET | 사용자 컨트랙트 조회 |

## TransactionBot

LaunchPad 이벤트 실시간 모니터링 → Supabase 저장.

| 이벤트 | 테이블 |
|--------|--------|
| TokenPurchased / TokenSold | `transactions` |
| Graduated / EmergencyGraduated | `graduations` |
| ContractDeployed | `token_deployments` |
