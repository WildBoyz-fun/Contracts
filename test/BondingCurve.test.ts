import { expect } from "chai"
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"

describe("BondingCurve", function () {
    const scale = 18;
    const epsilon = 0.000000000000001


    async function deployBondingCurve() {
        const bondingCurve = await hre.ethers.deployContract("BondingCurve")

        return { bondingCurve };
    }

    it("Should have more tokens those who purchase early", async function () {
        const { bondingCurve } = await loadFixture(deployBondingCurve);

        const ethDepositAmount = hre.ethers.parseEther("1");

        let tokenSupply = hre.ethers.parseEther("0");
        let depositBalance = hre.ethers.parseEther("0");

        const tokenAmount1 = await bondingCurve.calculatePurchaseReturn(tokenSupply, depositBalance, ethDepositAmount);

        tokenSupply += tokenAmount1;
        depositBalance += ethDepositAmount;

        const tokenAmount2 = await bondingCurve.calculatePurchaseReturn(tokenSupply, depositBalance, ethDepositAmount);

        tokenSupply += tokenAmount2;
        depositBalance += ethDepositAmount;

        const tokenAmount3 = await bondingCurve.calculatePurchaseReturn(tokenSupply, depositBalance, ethDepositAmount);

        tokenSupply += tokenAmount3;
        depositBalance += ethDepositAmount;

        console.log(hre.ethers.formatUnits(tokenAmount1, scale));
        console.log(hre.ethers.formatUnits(tokenAmount2, scale));
        console.log(hre.ethers.formatUnits(tokenAmount3, scale));

        expect(tokenAmount1).greaterThan(tokenAmount2);
        expect(tokenAmount2).greaterThan(tokenAmount3);
    })

    it("Should be returned same amount of deposit if you sell the same number of tokens", async function () {
        const { bondingCurve } = await loadFixture(deployBondingCurve);

        const ethDepositAmount = hre.ethers.parseEther("1");

        let tokenSupply = hre.ethers.parseEther("0");
        let depositBalance = hre.ethers.parseEther("0");

        const tokenAmount = await bondingCurve.calculatePurchaseReturn(tokenSupply, depositBalance, ethDepositAmount);

        tokenSupply += tokenAmount;
        depositBalance += ethDepositAmount;

        const ethAmount = await bondingCurve.calculateSaleReturn(tokenSupply, depositBalance, tokenAmount);

        tokenSupply -= tokenAmount;
        depositBalance -= ethAmount;

        expect(parseFloat(hre.ethers.formatEther(depositBalance))).lessThan(epsilon)
    })

    it("should be ensured that the number of tokens purchased does not exceed the maximum limit", async function () {
        const { bondingCurve } = await loadFixture(deployBondingCurve);

        let tokenSupply = hre.ethers.parseEther("0");
        let depositBalance = hre.ethers.parseEther("0");

        const ethDepositAmount = hre.ethers.parseEther("1");
        console.log(`deposit amount: ${parseFloat(hre.ethers.formatEther(ethDepositAmount))}`);

        const tokenAmount = await bondingCurve.calculatePurchaseReturn(tokenSupply, depositBalance, ethDepositAmount);
        console.log(`token amount: ${hre.ethers.formatUnits(tokenAmount, scale)}`);

        const ethAmount = await bondingCurve.calculatePurchaseBalance(tokenSupply, depositBalance, tokenAmount);
        console.log(`eth amount: ${parseFloat(hre.ethers.formatEther(ethAmount))}`)

        expect(Math.abs(parseFloat(hre.ethers.formatEther(ethDepositAmount - ethAmount)))).lessThan(epsilon)
    })
});
