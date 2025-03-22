import { expect } from "chai"
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"

describe("BondingCurveSwap", function () {
    const scale = 18;
    const epsilon = hre.ethers.parseEther("0.000000000000001")


    async function deployTokenAndSwap() {
        const [owner] = await hre.ethers.getSigners();

        const mintAmount = hre.ethers.parseUnits("1000000000", scale);

        const token = await hre.ethers.deployContract("MyToken", [owner.getAddress()]);

        const swap = await hre.ethers.deployContract("BondingCurveSwap", [token.getAddress()])

        await token.initialMint(swap.getAddress(), mintAmount);

        return { token, swap, owner, mintAmount };
    }

    it("Should be able to mint only once", async function () {
        const { token, owner, mintAmount } = await loadFixture(deployTokenAndSwap);

        await expect(token.initialMint(owner.getAddress(), mintAmount)).to.be.revertedWith("Already Minted")
    });

    it("Should have more tokens those who purchase early", async function () {
        const { token, swap } = await loadFixture(deployTokenAndSwap);

        const [_, account1, account2, account3] = await hre.ethers.getSigners();

        const ethAmount = hre.ethers.parseEther("1");

        await swap.connect(account1).purchase({ value: ethAmount });
        await swap.connect(account2).purchase({ value: ethAmount });
        await swap.connect(account3).purchase({ value: ethAmount });

        const tokenAmount1 = await token.balanceOf(account1.address);
        console.log(hre.ethers.formatUnits(tokenAmount1, scale));

        const tokenAmount2 = await token.balanceOf(account2.address);
        console.log(hre.ethers.formatUnits(tokenAmount2, scale));

        const tokenAmount3 = await token.balanceOf(account3.address);
        console.log(hre.ethers.formatUnits(tokenAmount3, scale));

        expect(tokenAmount1).greaterThan(tokenAmount2);
        expect(tokenAmount2).greaterThan(tokenAmount3);
    })

    it("Should be returned same amount of deposit if you sell the same number of tokens", async function () {
        const { token, swap } = await loadFixture(deployTokenAndSwap);

        const [_, account1] = await hre.ethers.getSigners();

        const ethAmount = hre.ethers.parseEther("1");

        await swap.connect(account1).purchase({ value: ethAmount });
        const tokenAmount = await token.balanceOf(account1.address);

        expect(await swap.getDepositBalance()).eq(ethAmount)

        await token.connect(account1).approve(swap.getAddress(), tokenAmount)
        await swap.connect(account1).sale(tokenAmount)

        expect(await swap.getDepositBalance()).lessThan(epsilon)
    })
});
