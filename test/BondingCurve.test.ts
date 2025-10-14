import { expect } from "chai"
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"

describe("BondingCurve", function () {
    const scale = 18;
    const epsilon = 0.000000000000001


    async function deployBondingCurve() {
        const formula = await hre.ethers.deployContract("BancorFormula");
        const bondingCurve = await hre.ethers.deployContract("BondingCurve", [await formula.getAddress()]);

        return { bondingCurve };
    }

    it("Should have more tokens those who purchase early", async function () {
        const { bondingCurve } = await loadFixture(deployBondingCurve);

        const ethDepositAmount = hre.ethers.parseEther("1");

        let tokenSupply = hre.ethers.parseEther("0");
        let depositBalance = hre.ethers.parseEther("0");
        let prevTokenAmount = null;

        for (let i = 0; i < 40; i++) {
            const tokenAmount = await bondingCurve.calculatePurchaseReturn(tokenSupply, depositBalance, ethDepositAmount);
            console.log(hre.ethers.formatUnits(tokenAmount, scale));

            tokenSupply += tokenAmount;
            depositBalance += ethDepositAmount;

            if (prevTokenAmount != null) {
                expect(prevTokenAmount).greaterThan(tokenAmount);
            }
            prevTokenAmount = tokenAmount;
        }

        console.log(`total token supplied: ${hre.ethers.formatUnits(tokenSupply, scale)}`);
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

        const ethDepositAmount1 = hre.ethers.parseEther("0.000000005");

        const tokenStartAmount = await bondingCurve.calculatePurchaseReturn(tokenSupply, depositBalance, ethDepositAmount1);
        const tokenStartPrice = toFloat(ethDepositAmount1)/toFloat(tokenStartAmount)
        console.log(`token start price: ${tokenStartPrice}`);

        const ethDepositAmount = hre.ethers.parseEther("40");
        console.log(`eth deposit amount: ${toFloat(ethDepositAmount)}`);

        const tokenAmount = await bondingCurve.calculatePurchaseReturn(tokenSupply, depositBalance, ethDepositAmount);
        console.log(`token sale amount: ${hre.ethers.formatUnits(tokenAmount, scale)}`);

        const tokenEndAmount = await bondingCurve.calculatePurchaseReturn(tokenAmount, ethDepositAmount, ethDepositAmount1);
        const tokenEndPrice = toFloat(ethDepositAmount1)/toFloat(tokenEndAmount)
        console.log(`token end price: ${tokenEndPrice}`);
        console.log(`Price increase ${((tokenEndPrice - tokenStartPrice)/tokenStartPrice) * 100}%`);

        const tokenProvideAmount = 200000000
        const ethProvideAmount = tokenEndPrice * tokenProvideAmount
        console.log(`LP ratio (token:eth) = (${tokenProvideAmount}:${ethProvideAmount})`)
        console.log(`Remaining ${toFloat(ethDepositAmount) - ethProvideAmount} eth`)

        const ethAmount = await bondingCurve.calculatePurchaseBalance(tokenSupply, depositBalance, tokenAmount);
        console.log(`eth amount: ${toFloat(ethAmount)}`)

        expect(Math.abs(toFloat(ethDepositAmount - ethAmount))).lessThan(epsilon)
    })

    function toFloat(amount: bigint): number {
        return parseFloat(hre.ethers.formatEther(amount))
    }
});
