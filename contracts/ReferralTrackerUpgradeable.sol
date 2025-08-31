// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

interface IOwnerGroup {
    function isOwner(address owner) external view returns (bool);
}

contract ReferralTrackerUpgradeable is 
    Initializable, 
    UUPSUpgradeable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable 
{
    enum ActivityType {
        ACCOUNT_CREATION,
        TOKEN_BUY,
        TOKEN_SELL
    }

    struct PointRewardConfig {
        int256 referrerReward;
        int256 refereeReward;
    }

    struct ReferralActivity {
        ActivityType activityType;
        int256 point;
        uint256 timestamp;
    }

    // === 상태 변수들 (기존과 동일한 순서 유지) ===
    IOwnerGroup public ownerGroup;
    
    mapping(ActivityType => PointRewardConfig) public rewardConfigs;
    mapping(address => ReferralActivity[]) public referralHistory;
    mapping(address => int256) public totalPoints;
    mapping(address => address) public referrers;
    mapping(address => bool) public accountRegistered;
    mapping(address => bool) public authorizedContracts;

    // === 이벤트들 ===
    event ReferralRecorded(address indexed user, ActivityType activityType, int256 point, uint256 timestamp);
    event ReferralRegistered(address indexed referee, address indexed referrer);
    event RewardConfigUpdated(ActivityType activityType, int256 referrerReward, int256 refereeReward);
    event AuthorizedContractUpdated(address indexed contractAddress, bool authorized);
    event RemoveAuthorizedContract(address indexed contractAddr);
    event OwnerGroupUpdated(address indexed oldOwnerGroup, address indexed newOwnerGroup);

    // === 모디파이어들 ===
    modifier onlyOwnerGroup() {
        require(ownerGroup.isOwner(msg.sender), "Not owner group member");
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender], "Not authorized");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // === 초기화 함수 ===
    function initialize(
        address ownerGroupAddress,
        address initialOwner
    ) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        ownerGroup = IOwnerGroup(ownerGroupAddress);

        // 초기 포인트 설정
        rewardConfigs[ActivityType.ACCOUNT_CREATION] = PointRewardConfig(100, 300); // 추천인 100, 피추천인 300
        rewardConfigs[ActivityType.TOKEN_BUY] = PointRewardConfig(1, 10); // 추천인 1, 피추천인 10
        rewardConfigs[ActivityType.TOKEN_SELL] = PointRewardConfig(0, -2); // 추천인 0, 피추천인 -2 (판매시 피추천인에게 포인트 차감)
    }

    // === 업그레이드 권한 관리 ===
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // === 관리자 함수들 ===
    
    // OwnerGroup 주소 업데이트 (owner만 가능)
    function updateOwnerGroup(address newOwnerGroupAddress) external onlyOwner {
        require(newOwnerGroupAddress != address(0), "Invalid owner group address");
        address oldOwnerGroup = address(ownerGroup);
        ownerGroup = IOwnerGroup(newOwnerGroupAddress);
        emit OwnerGroupUpdated(oldOwnerGroup, newOwnerGroupAddress);
    }

    // Activity별 포인트 보상 등록
    function setRewardConfig(
        ActivityType activityType, 
        int256 referrerReward, 
        int256 refereeReward
    ) external onlyOwnerGroup {
        rewardConfigs[activityType] = PointRewardConfig(referrerReward, refereeReward);
        emit RewardConfigUpdated(activityType, referrerReward, refereeReward);
    }

    // 이 Contract을 호출할 수 있는 Contract 등록
    function setAuthorizedContract(address contractAddress, bool authorized) external onlyOwnerGroup {
        require(contractAddress != address(0), "Invalid contract address");
        authorizedContracts[contractAddress] = authorized;
        emit AuthorizedContractUpdated(contractAddress, authorized);
    }

    // 이 Contract을 호출할 수 있는 Contract 제거
    function removeAuthorizedContract(address contractAddr) external onlyOwnerGroup {
        require(authorizedContracts[contractAddr], "Not authorized");
        authorizedContracts[contractAddr] = false;
        emit RemoveAuthorizedContract(contractAddr);
    }

    // === 사용자 함수들 ===

    // 추천인 등록
    function registerWithReferral(address referrer) external nonReentrant {
        require(!accountRegistered[msg.sender], "Already registered");
        require(referrer != msg.sender, "Cannot refer self");
        require(referrer != address(0), "Invalid referrer address");

        referrers[msg.sender] = referrer;
        accountRegistered[msg.sender] = true;

        emit ReferralRegistered(msg.sender, referrer);

        // 계정 생성 보상 기록 (내부 함수 사용)
        _recordReferralInternal(ActivityType.ACCOUNT_CREATION, msg.sender);
    }

    // 포인트 적립 (권한이 있는 컨트랙트에서만 호출 가능)
    function recordReferral(
        ActivityType activityType, 
        address user
    ) external onlyAuthorized nonReentrant {
        require(user != address(0), "Invalid user address");
        _recordReferralInternal(activityType, user);
    }

    // === 내부 함수들 ===

    // 내부 함수: 권한 체크 없이 포인트 기록
    function _recordReferralInternal(ActivityType activityType, address user) internal {
        PointRewardConfig memory config = rewardConfigs[activityType];

        address referrer = referrers[user];
        if (referrer != address(0) && config.referrerReward != 0) {
            referralHistory[referrer].push(
                ReferralActivity(activityType, config.referrerReward, block.timestamp)
            );
            totalPoints[referrer] += config.referrerReward;
            emit ReferralRecorded(referrer, activityType, config.referrerReward, block.timestamp);
        }

        if (config.refereeReward != 0) {
            referralHistory[user].push(
                ReferralActivity(activityType, config.refereeReward, block.timestamp)
            );
            totalPoints[user] += config.refereeReward;
            emit ReferralRecorded(user, activityType, config.refereeReward, block.timestamp);
        }
    }

    // === 조회 함수들 ===

    // 추천 보상 히스토리 조회
    function getReferralHistory(address user) external view returns (ReferralActivity[] memory) {
        return referralHistory[user];
    }

    // 현재 구현 컨트랙트 주소 반환
    function getImplementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    // 컨트랙트 버전 정보
    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    // === 데이터 마이그레이션 함수들 ===
    
    // 배치 추천인 등록 (마이그레이션용)
    function batchRegisterReferrals(
        address[] calldata users,
        address[] calldata referrersList
    ) external onlyOwner {
        require(users.length == referrersList.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < users.length; i++) {
            if (!accountRegistered[users[i]] && users[i] != referrersList[i] && referrersList[i] != address(0)) {
                referrers[users[i]] = referrersList[i];
                accountRegistered[users[i]] = true;
                emit ReferralRegistered(users[i], referrersList[i]);
            }
        }
    }

    // 배치 포인트 설정 (마이그레이션용)
    function batchSetTotalPoints(
        address[] calldata users,
        int256[] calldata points
    ) external onlyOwner {
        require(users.length == points.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < users.length; i++) {
            totalPoints[users[i]] = points[i];
        }
    }

    // 배치 히스토리 추가 (마이그레이션용)
    function batchAddHistory(
        address user,
        ReferralActivity[] calldata activities
    ) external onlyOwner {
        for (uint256 i = 0; i < activities.length; i++) {
            referralHistory[user].push(activities[i]);
        }
    }
}