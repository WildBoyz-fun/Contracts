// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IReferralTracker {
    enum ActivityType {
        ACCOUNT_CREATION,
        TOKEN_BUY,
        TOKEN_SELL
    }

    function recordReferral(ActivityType activityType, address user) external;
    function accountRegistered(address user) external view returns (bool);
    function referrers(address user) external view returns (address);
    function totalPoints(address user) external view returns (int256);
    function getClaimableReward(address user) external view returns (uint256);
    function currentEpoch() external view returns (uint256);
    function lastClaimedEpoch(address user) external view returns (uint256);
    function totalClaimed(address user) external view returns (uint256);
}
