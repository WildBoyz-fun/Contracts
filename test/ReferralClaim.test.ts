import { expect } from "chai"
import hre from "hardhat";
import { upgrades } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { ethers } from "hardhat";

describe("Referral Reward Claim", function () {

    async function deployReferral() {
        const [owner, referrer, user1, user2] = await hre.ethers.getSigners();

        const ownerGroupContract = await hre.ethers.deployContract("OwnerGroupContract", [[owner.address]]);
        const ReferralTrackerFactory = await hre.ethers.getContractFactory("ReferralTracker");
        const referralTracker = await upgrades.deployProxy(ReferralTrackerFactory, [
            await ownerGroupContract.getAddress()
        ], { kind: "uups" });
        await referralTracker.waitForDeployment();

        return { referralTracker, ownerGroupContract, owner, referrer, user1, user2 };
    }

    it("should allow owner to fund reward pool", async function () {
        const { referralTracker, owner } = await loadFixture(deployReferral);

        // Fund with 1 ETH, 0.001 ETH per point
        const ethPerPoint = ethers.parseEther("0.001");
        await referralTracker.connect(owner).fundRewardPool(ethPerPoint, {
            value: ethers.parseEther("1")
        });

        expect(await referralTracker.rewardPoolBalance()).to.equal(ethers.parseEther("1"));
        expect(await referralTracker.ethPerPoint()).to.equal(ethPerPoint);
        expect(await referralTracker.currentEpoch()).to.equal(1);
    });

    it("should allow users to claim rewards based on points", async function () {
        const { referralTracker, owner, referrer, user1 } = await loadFixture(deployReferral);

        // user1 registers with referrer → referrer gets 100 pts, user1 gets 300 pts
        await referralTracker.connect(user1).registerWithReferral(referrer.address);

        expect(await referralTracker.totalPoints(referrer.address)).to.equal(100);
        expect(await referralTracker.totalPoints(user1.address)).to.equal(300);

        // Owner funds reward pool: 0.0001 ETH per point
        const ethPerPoint = ethers.parseEther("0.0001");
        await referralTracker.connect(owner).fundRewardPool(ethPerPoint, {
            value: ethers.parseEther("1")
        });

        // Check claimable: referrer = 100 * 0.0001 = 0.01 ETH, user1 = 300 * 0.0001 = 0.03 ETH
        expect(await referralTracker.getClaimableReward(referrer.address)).to.equal(ethers.parseEther("0.01"));
        expect(await referralTracker.getClaimableReward(user1.address)).to.equal(ethers.parseEther("0.03"));

        // Referrer claims
        const balBefore = await hre.ethers.provider.getBalance(referrer.address);
        await referralTracker.connect(referrer).claimReward();
        const balAfter = await hre.ethers.provider.getBalance(referrer.address);

        // Balance increased (minus gas)
        expect(balAfter - balBefore).to.be.greaterThan(ethers.parseEther("0.009"));

        // Can't claim same epoch twice
        await expect(
            referralTracker.connect(referrer).claimReward()
        ).to.be.revertedWith("Already claimed this epoch");

        // Claimable should be 0 after claiming
        expect(await referralTracker.getClaimableReward(referrer.address)).to.equal(0);

        // user1 claims
        await referralTracker.connect(user1).claimReward();
        expect(await referralTracker.totalClaimed(user1.address)).to.equal(ethers.parseEther("0.03"));
    });

    it("should allow new epoch for repeated claims", async function () {
        const { referralTracker, owner, referrer, user1 } = await loadFixture(deployReferral);

        await referralTracker.connect(user1).registerWithReferral(referrer.address);

        // Epoch 1
        const ethPerPoint = ethers.parseEther("0.0001");
        await referralTracker.connect(owner).fundRewardPool(ethPerPoint, { value: ethers.parseEther("1") });
        await referralTracker.connect(referrer).claimReward();

        // Epoch 2 - owner funds again
        await referralTracker.connect(owner).fundRewardPool(ethPerPoint, { value: ethers.parseEther("1") });
        expect(await referralTracker.currentEpoch()).to.equal(2);

        // Referrer can claim again in new epoch
        await referralTracker.connect(referrer).claimReward();
        expect(await referralTracker.lastClaimedEpoch(referrer.address)).to.equal(2);
    });

    it("should reject claim with 0 or negative points", async function () {
        const { referralTracker, owner, user1 } = await loadFixture(deployReferral);

        // Fund pool
        await referralTracker.connect(owner).fundRewardPool(ethers.parseEther("0.001"), {
            value: ethers.parseEther("1")
        });

        // user1 has 0 points
        await expect(
            referralTracker.connect(user1).claimReward()
        ).to.be.revertedWith("No points to claim");
    });

    it("should reject non-owner from funding", async function () {
        const { referralTracker, user1 } = await loadFixture(deployReferral);

        await expect(
            referralTracker.connect(user1).fundRewardPool(ethers.parseEther("0.001"), {
                value: ethers.parseEther("1")
            })
        ).to.be.revertedWith("Not owner");
    });
});
