import { expect } from "chai"
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { ethers } from "hardhat";

describe("LaunchPadTokenTreasury", function () {
    

    async function initParams() {
        const [owner] = await hre.ethers.getSigners();
        
        const ownerGroupContract = await hre.ethers.deployContract("OwnerGroupContract", [[owner.address]])
        const launchPadTokenTreasury = await hre.ethers.deployContract("LaunchPanTokenTreasury", [await ownerGroupContract.getAddress()])

        return { launchPadTokenTreasury };
    }

    describe("Eth deposit / withdraw", function () {

        it("Deposit Test to Contract", async function () {
            const { launchPadTokenTreasury } = await loadFixture(initParams);
        
            const [owner] = await hre.ethers.getSigners();

            console.log(`contract owner ${owner.address}`)

            const sendAmount = hre.ethers.parseEther("1");
            const contractAddress = await launchPadTokenTreasury.getAddress();
        
            const ethTx = await owner.sendTransaction({
                to: contractAddress,
                value: sendAmount
            });
            await ethTx.wait();

            console.log(`Owner: (${owner.address}) sendAmount: ${sendAmount}`)

            const ethBalance = await ethers.provider.getBalance(contractAddress);
            console.log(`Contract(${contractAddress}) ETH Balance: ${ethBalance}`)

            expect(ethBalance).to.equals(sendAmount);

            const receiptTx = await launchPadTokenTreasury.connect(owner).sendEth(owner.address, hre.ethers.parseEther("0.5"));

            const receipt = await receiptTx.wait();
            
            // Assert event emitted
            const buyEvent = receipt?.logs
            .map(log => launchPadTokenTreasury.interface.parseLog(log))
            .find(e => e?.name === "WithdrawalEth");

            expect(buyEvent?.args.to).to.equal(owner.address);
            expect(buyEvent?.args.amount).to.equal(hre.ethers.parseEther("0.5"));

            console.log(`Contract After Eth Balance: ${await ethers.provider.getBalance(contractAddress)}`);

        });

    });
    
});
