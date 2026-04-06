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

    // Reward claim system
    uint256 public rewardPoolBalance;
    uint256 public ethPerPoint;          // wei per point (set by owner when distributing)
    uint256 public currentEpoch;         // incremented each distribution
    mapping(address => uint256) public lastClaimedEpoch; // track which epoch user last claimed
    mapping(address => uint256) public totalClaimed;     // total ETH claimed by user

    event ReferralRecorded(address indexed user, ActivityType activityType, int256 point, uint256 timestamp);
    event ReferralRegistered(address indexed referee, address indexed referrer);
    event RewardConfigUpdated(ActivityType activityType, int256 referrerReward, int256 refereeReward);
    event AuthorizedContractUpdated(address indexed contractAddress, bool authorized);
    event RemoveAuthorizedContract(address indexed contractAddr);
    event RewardPoolFunded(uint256 amount, uint256 ethPerPoint, uint256 epoch);
    event RewardClaimed(address indexed user, uint256 amount, int256 points, uint256 epoch);

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

        rewardConfigs[ActivityType.ACCOUNT_CREATION] = PointRewardConfig(100, 300);
        rewardConfigs[ActivityType.TOKEN_BUY] = PointRewardConfig(1, 10);
        rewardConfigs[ActivityType.TOKEN_SELL] = PointRewardConfig(0, -2);
    }

    receive() external payable {}

    // --- Point Reward Config ---

    function setRewardConfig(ActivityType activityType, int256 referrerReward, int256 refereeReward) external onlyOwner {
        rewardConfigs[activityType] = PointRewardConfig(referrerReward, refereeReward);
        emit RewardConfigUpdated(activityType, referrerReward, refereeReward);
    }

    // --- Authorization ---

    function setAuthorizedContract(address contractAddress, bool authorized) external onlyOwner {
        authorizedContracts[contractAddress] = authorized;
        emit AuthorizedContractUpdated(contractAddress, authorized);
    }

    function removeAuthorizedContract(address contractAddr) external onlyOwner {
        require(authorizedContracts[contractAddr], "Not authorized");
        authorizedContracts[contractAddr] = false;
        emit RemoveAuthorizedContract(contractAddr);
    }

    // --- Registration & Point Recording ---

    function registerWithReferral(address referrer) external {
        require(!accountRegistered[msg.sender], "Already registered");
        require(referrer != msg.sender, "Cannot refer self");

        referrers[msg.sender] = referrer;
        accountRegistered[msg.sender] = true;

        emit ReferralRegistered(msg.sender, referrer);
        _recordReferral(ActivityType.ACCOUNT_CREATION, msg.sender);
    }

    function recordReferral(ActivityType activityType, address user) public onlyAuthorized {
        _recordReferral(activityType, user);
    }

    function _recordReferral(ActivityType activityType, address user) internal {
        PointRewardConfig memory config = rewardConfigs[activityType];

        address referrer = referrers[user];
        if (referrer != address(0) && config.referrerReward != 0) {
            referralHistory[referrer].push(ReferralActivity(activityType, config.referrerReward, block.timestamp));
            totalPoints[referrer] += config.referrerReward;
            emit ReferralRecorded(referrer, activityType, config.referrerReward, block.timestamp);
        }

        if (config.refereeReward != 0) {
            referralHistory[user].push(ReferralActivity(activityType, config.refereeReward, block.timestamp));
            totalPoints[user] += config.refereeReward;
            emit ReferralRecorded(user, activityType, config.refereeReward, block.timestamp);
        }
    }

    // --- Reward Distribution & Claim ---

    /// @notice Owner funds the reward pool and sets the ETH-per-point rate for this epoch
    /// @param _ethPerPoint Wei amount per positive point
    function fundRewardPool(uint256 _ethPerPoint) external payable onlyOwner {
        require(msg.value > 0, "Must send ETH");
        require(_ethPerPoint > 0, "Rate must be > 0");

        rewardPoolBalance += msg.value;
        ethPerPoint = _ethPerPoint;
        currentEpoch++;

        emit RewardPoolFunded(msg.value, _ethPerPoint, currentEpoch);
    }

    /// @notice Users claim their reward based on points and current ethPerPoint rate
    function claimReward() external {
        require(ethPerPoint > 0, "No reward available");
        require(lastClaimedEpoch[msg.sender] < currentEpoch, "Already claimed this epoch");

        int256 points = totalPoints[msg.sender];
        require(points > 0, "No points to claim");

        uint256 reward = uint256(points) * ethPerPoint;
        require(reward <= rewardPoolBalance, "Insufficient reward pool");

        lastClaimedEpoch[msg.sender] = currentEpoch;
        rewardPoolBalance -= reward;
        totalClaimed[msg.sender] += reward;

        (bool success, ) = payable(msg.sender).call{value: reward}("");
        require(success, "Transfer failed");

        emit RewardClaimed(msg.sender, reward, points, currentEpoch);
    }

    /// @notice Check claimable reward for a user
    function getClaimableReward(address user) external view returns (uint256) {
        if (ethPerPoint == 0 || lastClaimedEpoch[user] >= currentEpoch) return 0;
        int256 points = totalPoints[user];
        if (points <= 0) return 0;
        return uint256(points) * ethPerPoint;
    }

    // --- View Functions ---

    function getReferralHistory(address user) external view returns (ReferralActivity[] memory) {
        return referralHistory[user];
    }
}
