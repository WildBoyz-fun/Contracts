# LaunchPad 업그레이드 가이드

이 가이드는 LaunchPad 컨트랙트의 업그레이드 가능한 버전 사용법에 대해 설명합니다.

## 개요

LaunchPad 컨트랙트는 이제 OpenZeppelin의 UUPS (Universal Upgradeable Proxy Standard) 패턴을 사용하여 업그레이드 가능합니다. 이를 통해:

- 컨트랙트 주소와 상태 데이터 유지
- 새로운 기능 및 버그 수정을 위한 로직 업데이트
- 기존 사용자 데이터 보존

## 주요 변경사항

### 1. LaunchPadUpgradeable 컨트랙트
- `Initializable`, `UUPSUpgradeable`, `OwnableUpgradeable`, `ReentrancyGuardUpgradeable` 상속
- `initialize()` 함수로 초기화 (생성자 대신)
- `_authorizeUpgrade()` 함수로 업그레이드 권한 관리
- 새로운 관리 함수들 추가

### 2. 새로운 기능
- `getImplementation()`: 현재 구현 컨트랙트 주소 조회
- `setTargetFundRaisingAmount()`: 목표 펀드레이징 금액 변경
- `setFeeRate()`: 수수료율 변경
- 가스 가격 관리 기능

## 배포 가이드

### 1. 최초 배포 (업그레이드 가능한 버전)

```bash
# 로컬 네트워크
npm run deploy:upgradeable

# Monad 테스트넷
npm run deploy:upgradeable:monad
```

### 2. 업그레이드 실행

```bash
# 프록시 주소 설정
export PROXY_ADDRESS="0x프록시주소"

# 로컬 네트워크에서 업그레이드
npm run upgrade:launchpad

# Monad 테스트넷에서 업그레이드  
npm run upgrade:launchpad:monad
```

### 3. 업그레이드 검증

```bash
# 프록시 주소 설정
export PROXY_ADDRESS="0x프록시주소"

# 로컬 네트워크에서 검증
npm run verify:upgrade

# Monad 테스트넷에서 검증
npm run verify:upgrade:monad
```

## 업그레이드 프로세스

### 1. 새 구현 컨트랙트 배포
- 새로운 `LaunchPadUpgradeable` 컨트랙트 배포
- 기존 프록시는 그대로 유지

### 2. 프록시 업그레이드
- 프록시의 구현 주소를 새 컨트랙트로 변경
- 모든 상태 데이터는 프록시에 저장되어 있어 보존

### 3. 검증
- 업그레이드 성공 여부 확인
- 기존 데이터 무결성 검증
- 새 기능 동작 확인

## 중요 사항

### 업그레이드 권한
- 컨트랙트 owner만 업그레이드 가능
- `_authorizeUpgrade()` 함수에서 권한 검증

### 상태 변수 호환성
- 새 버전에서는 기존 상태 변수 순서 유지 필요
- 새로운 상태 변수는 끝에 추가만 가능
- 기존 변수 타입 변경 불가

### 초기화 함수
- `initialize()` 함수는 한 번만 호출 가능
- 업그레이드 시 초기화가 필요한 경우 별도 함수 사용

## 주소 관리

### 기존 방식 (Non-Upgradeable)
```json
{
  "LaunchPadModule#LaunchPad": "0x컨트랙트주소"
}
```

### 새로운 방식 (Upgradeable)
```json
{
  "LaunchPadUpgradeableModule#LaunchPadImpl": "0x구현주소",
  "LaunchPadUpgradeableModule#Proxy": "0x프록시주소"
}
```

**중요**: 프론트엔드와 다른 시스템에서는 항상 **프록시 주소**를 사용해야 합니다.

## 마이그레이션 체크리스트

### 배포 전
- [ ] 새 컨트랙트 코드 검토
- [ ] 상태 변수 호환성 확인
- [ ] 테스트 네트워크에서 테스트

### 배포 중
- [ ] 구현 컨트랙트 배포
- [ ] 프록시 배포 및 초기화
- [ ] 배포된 주소 기록

### 배포 후
- [ ] 프록시 기능 검증
- [ ] 기존 데이터 무결성 확인
- [ ] 프론트엔드/백엔드 주소 업데이트

## 롤백 절차

업그레이드에 문제가 발생한 경우:

1. 이전 구현 컨트랙트 주소 확인
2. `upgradeToAndCall()` 함수로 이전 버전으로 롤백
3. 상태 데이터 무결성 검증

## 모니터링

업그레이드 후 모니터링할 항목:
- 컨트랙트 상태 데이터 일관성
- 새로운 기능 정상 작동
- 가스 비용 변화
- 이벤트 로그 정상 발생

## 지원

업그레이드 과정에서 문제가 발생하면 다음을 확인하세요:
- 프록시 주소와 구현 주소 구분
- 업그레이드 권한 (owner 계정 사용)
- 네트워크 설정 및 가스비
- 컨트랙트 상태 변수 호환성