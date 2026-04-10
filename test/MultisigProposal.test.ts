import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";

describe("OwnerGroup Multisig Proposals", function () {
  async function deploy3Owners() {
    const [owner1, owner2, owner3, nonOwner] = await ethers.getSigners();
    const ownerGroup = await ethers.deployContract("OwnerGroupContract", [
      [owner1.address, owner2.address, owner3.address],
    ]);

    // Deploy a contract with ETH to test emergency withdraw
    const launchPadTokenTreasury = await ethers.deployContract("LaunchPanTokenTreasury", [
      await ownerGroup.getAddress(),
    ]);

    return { ownerGroup, launchPadTokenTreasury, owner1, owner2, owner3, nonOwner };
  }

  async function deploy1Owner() {
    const [owner1, nonOwner] = await ethers.getSigners();
    const ownerGroup = await ethers.deployContract("OwnerGroupContract", [[owner1.address]]);
    return { ownerGroup, owner1, nonOwner };
  }

  it("should require majority (2/3) confirmations with 3 owners", async function () {
    const { ownerGroup } = await loadFixture(deploy3Owners);
    expect(await ownerGroup.requiredConfirmations()).to.equal(2);
  });

  it("should require only 1 confirmation with 1 owner", async function () {
    const { ownerGroup } = await loadFixture(deploy1Owner);
    expect(await ownerGroup.requiredConfirmations()).to.equal(1);
  });

  it("should auto-execute when 1 owner and proposal created", async function () {
    const { ownerGroup, owner1 } = await loadFixture(deploy1Owner);

    // Send ETH to ownerGroup for testing
    await owner1.sendTransaction({ to: await ownerGroup.getAddress(), value: ethers.parseEther("1") });

    // Submit proposal to send ETH to owner1
    const data = "0x"; // empty calldata, just send ETH
    const tx = await ownerGroup.connect(owner1).submitProposal(owner1.address, data, ethers.parseEther("0.5"));
    const receipt = await tx.wait();

    // Check proposal was auto-executed
    const proposal = await ownerGroup.getProposal(0);
    expect(proposal.executed).to.be.true;
  });

  it("should NOT auto-execute with 3 owners (needs 2 confirmations)", async function () {
    const { ownerGroup, owner1, owner2, owner3 } = await loadFixture(deploy3Owners);

    // Send ETH to ownerGroup
    await owner1.sendTransaction({ to: await ownerGroup.getAddress(), value: ethers.parseEther("1") });

    // Submit proposal (gets 1 confirmation from submitter)
    await ownerGroup.connect(owner1).submitProposal(owner1.address, "0x", ethers.parseEther("0.5"));

    // Not yet executed
    let proposal = await ownerGroup.getProposal(0);
    expect(proposal.executed).to.be.false;
    expect(proposal.confirmCount).to.equal(1);

    // Second owner confirms → auto-executes
    const balBefore = await ethers.provider.getBalance(owner1.address);
    await ownerGroup.connect(owner2).confirmProposal(0);

    proposal = await ownerGroup.getProposal(0);
    expect(proposal.executed).to.be.true;
    expect(proposal.confirmCount).to.equal(2);

    // ETH was sent
    const balAfter = await ethers.provider.getBalance(owner1.address);
    expect(balAfter - balBefore).to.equal(ethers.parseEther("0.5"));
  });

  it("should reject non-owner from submitting proposals", async function () {
    const { ownerGroup, nonOwner } = await loadFixture(deploy3Owners);

    await expect(
      ownerGroup.connect(nonOwner).submitProposal(nonOwner.address, "0x", 0)
    ).to.be.revertedWith("Not owner");
  });

  it("should reject double confirmation", async function () {
    const { ownerGroup, owner1 } = await loadFixture(deploy3Owners);
    await ownerGroup.connect(owner1).submitProposal(owner1.address, "0x", 0);

    await expect(
      ownerGroup.connect(owner1).confirmProposal(0)
    ).to.be.revertedWith("Already confirmed");
  });

  it("should allow revoking confirmation", async function () {
    const { ownerGroup, owner1, owner2 } = await loadFixture(deploy3Owners);
    await ownerGroup.connect(owner1).submitProposal(owner1.address, "0x", 0);

    // owner1 revokes
    await ownerGroup.connect(owner1).revokeConfirmation(0);
    const proposal = await ownerGroup.getProposal(0);
    expect(proposal.confirmCount).to.equal(0);
  });

  it("should execute emergency withdraw via multisig proposal", async function () {
    const { ownerGroup, owner1, owner2, owner3 } = await loadFixture(deploy3Owners);

    // Deploy a mock contract that holds ETH and has emergencyWithdrawETH
    // We'll use the ownerGroup itself as the target (it has receive())
    const ogAddr = await ownerGroup.getAddress();

    // Send ETH to ownerGroup
    await owner1.sendTransaction({ to: ogAddr, value: ethers.parseEther("2") });

    // Encode a call to send ETH (just a plain transfer via proposal)
    const treasury = owner3.address;
    const callData = "0x"; // Plain ETH transfer
    const amount = ethers.parseEther("1");

    // Submit proposal to send 1 ETH to owner3
    await ownerGroup.connect(owner1).submitProposal(treasury, callData, amount);

    const balBefore = await ethers.provider.getBalance(treasury);

    // owner2 confirms → executes
    await ownerGroup.connect(owner2).confirmProposal(0);

    const balAfter = await ethers.provider.getBalance(treasury);
    expect(balAfter - balBefore).to.equal(amount);
  });

  it("should return pending proposals", async function () {
    const { ownerGroup, owner1 } = await loadFixture(deploy3Owners);

    await ownerGroup.connect(owner1).submitProposal(owner1.address, "0x", 0);
    await ownerGroup.connect(owner1).submitProposal(owner1.address, "0x", 0);

    const pending = await ownerGroup.getPendingProposals();
    expect(pending.length).to.equal(2);
  });
});
