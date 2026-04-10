// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IOwnerGroupContract} from "./libs/IOwnerGroupContract.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IOwnerGroup {
    function isOwner(address owner) external view returns (bool);
}

contract ReferralTracker is Initializable, UUPSUpgradeable {
    enum ActivityType { ACCOUNT_CREATION, TOKEN_BUY, TOKEN_SELL }

    struct PointRewardConfig { int256 referrerReward; int256 refereeReward; }
    struct ReferralActivity { ActivityType activityType; int256 point; uint256 timestamp; }

    int256 public constant MAX_POINTS = 1_000_000_000; // 1 billion point cap
    int256 public constant MIN_POINTS = -1_000_000;    // minimum negative cap

    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    IOwnerGroup public ownerGroup;

    mapping(ActivityType => PointRewardConfig) public rewardConfigs;
    mapping(address => ReferralActivity[]) public referralHistory;
    mapping(address => int256) public totalPoints;
    mapping(address => address) public referrers;
    mapping(address => bool) public accountRegistered;
    mapping(address => bool) public authorizedContracts;

    uint256 public rewardPoolBalance;
    uint256 public ethPerPoint;
    uint256 public currentEpoch;
    mapping(address => uint256) public lastClaimedEpoch;
    mapping(address => uint256) public totalClaimed;

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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address ownerGroupAddress) external initializer {
        _reentrancyStatus = NOT_ENTERED;
        ownerGroup = IOwnerGroup(ownerGroupAddress);
        rewardConfigs[ActivityType.ACCOUNT_CREATION] = PointRewardConfig(100, 300);
        rewardConfigs[ActivityType.TOKEN_BUY] = PointRewardConfig(1, 10);
        rewardConfigs[ActivityType.TOKEN_SELL] = PointRewardConfig(0, -2);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    receive() external payable {}

    function setOwnerGroup(address newOwnerGroup) external onlyOwner {
        require(newOwnerGroup != address(0), "Invalid");
        ownerGroup = IOwnerGroup(newOwnerGroup);
    }

    function setRewardConfig(ActivityType activityType, int256 referrerReward, int256 refereeReward) external onlyOwner {
        rewardConfigs[activityType] = PointRewardConfig(referrerReward, refereeReward);
        emit RewardConfigUpdated(activityType, referrerReward, refereeReward);
    }

    function setAuthorizedContract(address contractAddress, bool authorized) external onlyOwner {
        authorizedContracts[contractAddress] = authorized;
        emit AuthorizedContractUpdated(contractAddress, authorized);
    }

    function removeAuthorizedContract(address contractAddr) external onlyOwner {
        require(authorizedContracts[contractAddr], "Not authorized");
        authorizedContracts[contractAddr] = false;
        emit RemoveAuthorizedContract(contractAddr);
    }

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
            int256 newPoints = totalPoints[referrer] + config.referrerReward;
            if (newPoints > MAX_POINTS) newPoints = MAX_POINTS;
            if (newPoints < MIN_POINTS) newPoints = MIN_POINTS;
            referralHistory[referrer].push(ReferralActivity(activityType, config.referrerReward, block.timestamp));
            totalPoints[referrer] = newPoints;
            emit ReferralRecorded(referrer, activityType, config.referrerReward, block.timestamp);
        }
        if (config.refereeReward != 0) {
            int256 newPoints = totalPoints[user] + config.refereeReward;
            if (newPoints > MAX_POINTS) newPoints = MAX_POINTS;
            if (newPoints < MIN_POINTS) newPoints = MIN_POINTS;
            referralHistory[user].push(ReferralActivity(activityType, config.refereeReward, block.timestamp));
            totalPoints[user] = newPoints;
            emit ReferralRecorded(user, activityType, config.refereeReward, block.timestamp);
        }
    }

    function fundRewardPool(uint256 _ethPerPoint) external payable onlyOwner {
        require(msg.value > 0, "Must send ETH");
        require(_ethPerPoint > 0, "Rate must be > 0");
        rewardPoolBalance += msg.value;
        ethPerPoint = _ethPerPoint;
        currentEpoch++;
        emit RewardPoolFunded(msg.value, _ethPerPoint, currentEpoch);
    }

    function claimReward() external nonReentrant {
        require(ethPerPoint > 0, "No reward available");
        require(lastClaimedEpoch[msg.sender] < currentEpoch, "Already claimed this epoch");
        int256 points = totalPoints[msg.sender];
        require(points > 0, "No points to claim");
        uint256 reward = uint256(points) * ethPerPoint;
        require(reward <= rewardPoolBalance, "Insufficient reward pool");

        // Effects — reset points to prevent repeated claims across epochs
        lastClaimedEpoch[msg.sender] = currentEpoch;
        totalPoints[msg.sender] = 0;
        rewardPoolBalance -= reward;
        totalClaimed[msg.sender] += reward;

        // Interaction
        (bool success, ) = payable(msg.sender).call{value: reward}("");
        require(success, "Transfer failed");
        emit RewardClaimed(msg.sender, reward, points, currentEpoch);
    }

    function getClaimableReward(address user) external view returns (uint256) {
        if (ethPerPoint == 0 || lastClaimedEpoch[user] >= currentEpoch) return 0;
        int256 points = totalPoints[user];
        if (points <= 0) return 0;
        return uint256(points) * ethPerPoint;
    }

    function getReferralHistory(address user) external view returns (ReferralActivity[] memory) {
        return referralHistory[user];
    }

    /// @notice Emergency withdraw ETH stuck in contract
    function emergencyWithdrawETH(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid address");
        require(address(this).balance >= amount, "Insufficient balance");
        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "Transfer failed");
    }

    uint256 private _reentrancyStatus;

    modifier nonReentrant() {
        require(_reentrancyStatus != ENTERED, "ReentrancyGuard: reentrant call");
        _reentrancyStatus = ENTERED;
        _;
        _reentrancyStatus = NOT_ENTERED;
    }

    uint256[49] private __gap;
}
