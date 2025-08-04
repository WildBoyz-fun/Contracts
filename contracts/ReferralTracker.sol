// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IOwnerGroupContract} from "./libs/IOwnerGroupContract.sol";

interface IOwnerGroup {
    function isOwner(address owner) external view returns (bool);
}

contract ReferralTracker {
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

    IOwnerGroup public ownerGroup;

    mapping(ActivityType => PointRewardConfig) public rewardConfigs;
    mapping(address => ReferralActivity[]) public referralHistory;
    mapping(address => int256) public totalPoints;
    mapping(address => address) public referrers;
    mapping(address => bool) public accountRegistered;
    mapping(address => bool) public authorizedContracts;

    event ReferralRecorded(address indexed user, ActivityType activityType, int256 point, uint256 timestamp);
    event ReferralRegistered(address indexed referee, address indexed referrer);
    event RewardConfigUpdated(ActivityType activityType, int256 referrerReward, int256 refereeReward);
    event AuthorizedContractUpdated(address indexed contractAddress, bool authorized);
    event RemoveAuthorizedContract(address indexed contractAddr);

    modifier onlyOwner() {
        require(ownerGroup.isOwner(msg.sender), "Not owner");
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender], "Not authorized");
        _;
    }

    constructor(address ownerGroupAddress) {
        ownerGroup = IOwnerGroup(ownerGroupAddress);

        // 초기 포인트 설정
        rewardConfigs[ActivityType.ACCOUNT_CREATION] = PointRewardConfig(100, 300); // 추천인 100, 피추천인 300
        rewardConfigs[ActivityType.TOKEN_BUY] = PointRewardConfig(1, 10); // 추천인 1, 피추천인 10
        rewardConfigs[ActivityType.TOKEN_SELL] = PointRewardConfig(0, -2); // 추천인 0, 피추천인 -2 (판매시 피추천인에게 포인트 차감)
    }

    // Activity별 포인트 보상 등록
    function setRewardConfig(ActivityType activityType, int256 referrerReward, int256 refereeReward) external onlyOwner {
        rewardConfigs[activityType] = PointRewardConfig(referrerReward, refereeReward);
        emit RewardConfigUpdated(activityType, referrerReward, refereeReward);
    }

    // 이 Contract을 호출할 수 있는 Contract 등록
    // owner만 호출 가능
    function setAuthorizedContract(address contractAddress, bool authorized) external onlyOwner {
        authorizedContracts[contractAddress] = authorized;
        emit AuthorizedContractUpdated(contractAddress, authorized);
    }

    // 이 Contract을 호출할 수 있는 Contract 제거
    // owner만 호출 가능
    function removeAuthorizedContract(address contractAddr) external onlyOwner {
        require(authorizedContracts[contractAddr], "Not authorized");
        authorizedContracts[contractAddr] = false;
        emit RemoveAuthorizedContract(contractAddr);
    }    

    // 추천인 등록
    // referrer: 추천인 주소, self referral은 불가능
    // accountRegistered: 이미 추천일을 등록한 계정인지 확인
    // user가 처음 등록할 때 호출
    function registerWithReferral(address referrer) external {
        require(!accountRegistered[msg.sender], "Already registered");
        require(referrer != msg.sender, "Cannot refer self");

        referrers[msg.sender] = referrer;
        accountRegistered[msg.sender] = true;

        emit ReferralRegistered(msg.sender, referrer);

        // 계정 생성 보상 기록 (내부 함수 사용)
        _recordReferralInternal(ActivityType.ACCOUNT_CREATION, msg.sender);
    }

    // 포인트 적립(활동에 따른 추천인, 피추천인 포인트 등록, 추천인이 없으면 피추천인만 적립)
    // user가 활동을 할 때마다 호출
    // 예: 토큰 구매, 판매 등
    function recordReferral(ActivityType activityType, address user) public onlyAuthorized {
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

    // 내부 함수: 권한 체크 없이 포인트 기록 (컨트랙트 내부에서만 사용)
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

    // 추천 보상 히스토리 조회
    function getReferralHistory(address user) external view returns (ReferralActivity[] memory) {
        return referralHistory[user];
    }
} 
