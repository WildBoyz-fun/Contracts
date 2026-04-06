import { expect } from "chai"
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"

describe("OwnerGroupContract", function () {

    async function deploy() {
        const [owner1, owner2, owner3, nonOwner] = await hre.ethers.getSigners();

        const ownerGroup = await hre.ethers.deployContract("OwnerGroupContract", [
            [owner1.address, owner2.address]
        ]);

        return { ownerGroup, owner1, owner2, owner3, nonOwner };
    }

    it("should initialize with multiple owners", async function () {
        const { ownerGroup, owner1, owner2 } = await loadFixture(deploy);

        expect(await ownerGroup.getOwnerCount()).to.equal(2);
        expect(await ownerGroup.isOwner(owner1.address)).to.be.true;
        expect(await ownerGroup.isOwner(owner2.address)).to.be.true;

        const owners = await ownerGroup.getOwners();
        expect(owners.length).to.equal(2);
        expect(owners).to.include(owner1.address);
        expect(owners).to.include(owner2.address);
    });

    it("should allow owner to add new owner", async function () {
        const { ownerGroup, owner1, owner3 } = await loadFixture(deploy);

        await ownerGroup.connect(owner1).registerOwner(owner3.address);

        expect(await ownerGroup.isOwner(owner3.address)).to.be.true;
        expect(await ownerGroup.getOwnerCount()).to.equal(3);

        const owners = await ownerGroup.getOwners();
        expect(owners).to.include(owner3.address);
    });

    it("should allow owner to remove another owner", async function () {
        const { ownerGroup, owner1, owner2 } = await loadFixture(deploy);

        await ownerGroup.connect(owner1).unRegisterOwner(owner2.address);

        expect(await ownerGroup.isOwner(owner2.address)).to.be.false;
        expect(await ownerGroup.getOwnerCount()).to.equal(1);

        const owners = await ownerGroup.getOwners();
        expect(owners.length).to.equal(1);
        expect(owners[0]).to.equal(owner1.address);
    });

    it("should not allow removing self", async function () {
        const { ownerGroup, owner1 } = await loadFixture(deploy);

        await expect(
            ownerGroup.connect(owner1).unRegisterOwner(owner1.address)
        ).to.be.revertedWith("Cannot remove self");
    });

    it("should not allow removing last owner", async function () {
        const { ownerGroup, owner1, owner2 } = await loadFixture(deploy);

        // Remove owner2 first
        await ownerGroup.connect(owner1).unRegisterOwner(owner2.address);

        // Now only owner1 remains — owner2 tries to remove owner1 (should fail, not owner)
        await expect(
            ownerGroup.connect(owner2).unRegisterOwner(owner1.address)
        ).to.be.revertedWith("Not owner");
    });

    it("should reject non-owner actions", async function () {
        const { ownerGroup, owner3, nonOwner } = await loadFixture(deploy);

        await expect(
            ownerGroup.connect(nonOwner).registerOwner(owner3.address)
        ).to.be.revertedWith("Not owner");

        await expect(
            ownerGroup.connect(nonOwner).unRegisterOwner(owner3.address)
        ).to.be.revertedWith("Not owner");
    });

    it("should reject duplicate owner registration", async function () {
        const { ownerGroup, owner1, owner2 } = await loadFixture(deploy);

        await expect(
            ownerGroup.connect(owner1).registerOwner(owner2.address)
        ).to.be.revertedWith("Already registered");
    });

    it("should keep ownerList consistent after add/remove", async function () {
        const { ownerGroup, owner1, owner2, owner3 } = await loadFixture(deploy);

        // Add owner3
        await ownerGroup.connect(owner1).registerOwner(owner3.address);
        expect(await ownerGroup.getOwnerCount()).to.equal(3);

        // Remove owner2 (middle of list)
        await ownerGroup.connect(owner1).unRegisterOwner(owner2.address);

        const owners = await ownerGroup.getOwners();
        expect(owners.length).to.equal(2);
        expect(owners).to.include(owner1.address);
        expect(owners).to.include(owner3.address);
        expect(owners).to.not.include(owner2.address);
    });
});
