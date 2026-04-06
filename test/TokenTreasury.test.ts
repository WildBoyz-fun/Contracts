import { expect } from "chai"
import hre from "hardhat";
import { loadFixture, time } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { ethers } from "hardhat";

describe("TokenTreasury Access Control", function () {

    async function deployTreasury() {
        const [owner, voter, attacker, recipient] = await hre.ethers.getSigners();

        const ownerGroupContract = await hre.ethers.deployContract("OwnerGroupContract", [[owner.address]]);
        const treasury = await hre.ethers.deployContract("TokenTreasury", [
            await ownerGroupContract.getAddress()
        ]);

        return { treasury, ownerGroupContract, owner, voter, attacker, recipient };
    }

    it("should restrict executeProposal to admin only", async function () {
        const { treasury, attacker } = await loadFixture(deployTreasury);

        // attacker tries to execute a non-existent proposal
        await expect(
            treasury.connect(attacker).executeProposal(1)
        ).to.be.revertedWith("Not admin");
    });

    it("should restrict registerDAOToken to admin only", async function () {
        const { treasury, attacker } = await loadFixture(deployTreasury);

        await expect(
            treasury.connect(attacker).registerDAOToken(ethers.ZeroAddress)
        ).to.be.revertedWith("Not admin");
    });

    it("should allow admin to execute passed proposal", async function () {
        const { treasury, ownerGroupContract, owner, voter, recipient } = await loadFixture(deployTreasury);

        // Create a mock ERC404-like token for voting qualification
        // We'll use a simple mock that returns balances
        const mockToken = await hre.ethers.deployContract("MockERC20", ["DAO Token", "DAO"]);

        // Register token
        await treasury.connect(owner).registerDAOToken(await mockToken.getAddress());

        // Give voter enough tokens (>1% of total supply)
        const totalSupply = ethers.parseEther("1000");
        await mockToken.mint(voter.address, totalSupply); // 100% of supply

        // Fund the treasury
        await owner.sendTransaction({
            to: await treasury.getAddress(),
            value: ethers.parseEther("10")
        });

        // Voter creates a proposal (voting period: 60 seconds)
        await treasury.connect(voter).createProposal(
            await mockToken.getAddress(),
            "Send 1 ETH to recipient",
            ethers.parseEther("1"),
            recipient.address,
            60
        );

        // Voter votes yes
        await treasury.connect(voter).vote(await mockToken.getAddress(), 1, true);

        // Fast-forward past deadline
        await time.increase(61);

        // Non-admin cannot execute
        await expect(
            treasury.connect(voter).executeProposal(1)
        ).to.be.revertedWith("Not admin");

        // Admin can execute
        const recipientBalanceBefore = await hre.ethers.provider.getBalance(recipient.address);
        await treasury.connect(owner).executeProposal(1);
        const recipientBalanceAfter = await hre.ethers.provider.getBalance(recipient.address);

        expect(recipientBalanceAfter - recipientBalanceBefore).to.equal(ethers.parseEther("1"));

        // Cannot execute twice
        await expect(
            treasury.connect(owner).executeProposal(1)
        ).to.be.revertedWith("Already executed");
    });
});
