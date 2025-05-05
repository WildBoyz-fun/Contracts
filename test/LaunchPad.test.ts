import { expect } from "chai"
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { ethers } from "hardhat";
import { LaunchPanTokenTreasury__factory } from "../typechain-types";

describe("LaunchPad", function () {
    
    async function deployBondingCurve() {
        const [owner] = await hre.ethers.getSigners();
        const bondingCurve = await hre.ethers.deployContract("BondingCurve")
        const launchPad = await hre.ethers.deployContract("LaunchPad", [await bondingCurve.getAddress()])

        return { launchPad };
    }

    describe("Contract Deploy And Status Check", function () {
        it("contract must be deployed before checking status", async function () {
            const { launchPad} = await loadFixture(deployBondingCurve);
        
            const fakeContractAddress = ethers.Wallet.createRandom().address;
            
            await expect(launchPad.getContractSaleStatus(fakeContractAddress)).to.be.revertedWith("CND");
        });

        it("contract is deployed. Checking Owner and Contract is not On Sale", async function () {
            const { launchPad } = await loadFixture(deployBondingCurve);
        
            const [owner] = await hre.ethers.getSigners();

            console.log(`contract owner ${owner.address}`)

            const tx = await launchPad.connect(owner).createBioDiversityERC404Token("MyToken", "MT", ethers.parseEther("1000000000"));
            const receipt = await tx.wait();
            
            const event = receipt?.logs
                        .map(log => launchPad.interface.parseLog(log))
                        .find(e => e?.name === "ContractDeployed");
            
            const contractAddress = event?.args.contractAddress;
            
            expect(event?.args.deployedBy).to.equals(owner.address);
            expect(await launchPad.getContractSaleStatus(contractAddress)).to.equals(false);
        });

        it("contract is deployed. Checking Owner and Contract is On Sale", async function () {
            const { launchPad } = await loadFixture(deployBondingCurve);
        
            const [owner] = await hre.ethers.getSigners();

            console.log(`contract owner ${owner.address}`)

            const tx = await launchPad.connect(owner).createBioDiversityERC404Token("MyToken", "MT", ethers.parseEther("1000000000"));
            const receipt = await tx.wait();
            
            const event = receipt?.logs
                        .map(log => launchPad.interface.parseLog(log))
                        .find(e => e?.name === "ContractDeployed");
            
            const contractAddress = event?.args.contractAddress;
            
            expect(event?.args.deployedBy).to.equals(owner.address);
            
            await launchPad.connect(owner).startSale(contractAddress);

            expect(await launchPad.getContractSaleStatus(contractAddress)).to.equals(true);
        });


        it("contract is deployed. Contract Sale is halted", async function () {
            const { launchPad } = await loadFixture(deployBondingCurve);
        
            const [owner] = await hre.ethers.getSigners();

            console.log(`contract owner ${owner.address}`)

            const tx = await launchPad.connect(owner).createBioDiversityERC404Token("MyToken", "MT", ethers.parseEther("1000000000"));
            const receipt = await tx.wait();
            
            const event = receipt?.logs
                        .map(log => launchPad.interface.parseLog(log))
                        .find(e => e?.name === "ContractDeployed");
            
            const contractAddress = event?.args.contractAddress;
            
            expect(event?.args.deployedBy).to.equals(owner.address);
            
            await launchPad.connect(owner).startSale(contractAddress);
            expect(await launchPad.getContractSaleStatus(contractAddress)).to.equals(true);
            await launchPad.connect(owner).endSale(contractAddress);
            expect(await launchPad.getContractSaleStatus(contractAddress)).to.equals(false);
        });

        it("contract is deployed. Contract Count 1", async function () {
            const { launchPad } = await loadFixture(deployBondingCurve);
        
            const [owner] = await hre.ethers.getSigners();

            console.log(`contract owner ${owner.address}`)

            const tx = await launchPad.connect(owner).createBioDiversityERC404Token("MyToken", "MT", ethers.parseEther("1000000000"));
            const receipt = await tx.wait();
            
            const event = receipt?.logs
                        .map(log => launchPad.interface.parseLog(log))
                        .find(e => e?.name === "ContractDeployed");
        
            
            expect(event?.args.deployedBy).to.equals(owner.address);
            
            expect(await launchPad.getLaunchedContractCount()).to.equals(1);
            
        });

    });

    describe("Contract Buy / Sell Test", function () {
        it("verify buy token", async function () {
            const { launchPad} = await loadFixture(deployBondingCurve);
            const [owner, buyer] = await hre.ethers.getSigners();
            
            const balance = await hre.ethers.provider.getBalance(owner.address);
        
            console.log(`${buyer.address} has a wallet balance: ${balance}`)

            const tx = await launchPad.connect(owner).createBioDiversityERC404Token("MyToken", "MT", ethers.parseEther("1000000000"));
            const receipt = await tx.wait();
            
            const event = receipt?.logs
                        .map(log => launchPad.interface.parseLog(log))
                        .find(e => e?.name === "ContractDeployed");
            
            const contractAddress = event?.args.contractAddress;
            
             // Start the token sale
            await launchPad.startSale(contractAddress);

            const token = await hre.ethers.getContractAt("IERC20", contractAddress);
            const totalSupply = await token.totalSupply();       

            console.log(`TotalSupply: ${hre.ethers.formatUnits(totalSupply, 18)}`)
            
            // Buy tokens with 1 ETH
            const buyTx = await launchPad.connect(buyer).buyToken(contractAddress, { value: ethers.parseEther("0.01"),});
            const buyReceipt = await buyTx.wait();

            // Assert event emitted
            const buyEvent = buyReceipt?.logs
            .map(log => launchPad.interface.parseLog(log))
            .find(e => e?.name === "TokensPurchased");

            const afterTokenBalance = await token.balanceOf(await launchPad.getAddress());
            const buyerTokenBalance = await token.balanceOf(buyer.address);

            console.log(`launchPad: ${await launchPad.getAddress()}, token balance: ${hre.ethers.formatUnits(afterTokenBalance, 18)}`)
            console.log(`buyer: ${buyer.address}, token balance: ${hre.ethers.formatUnits(buyerTokenBalance, 18)}`)
            
            expect(buyEvent?.args.buyer).to.equal(buyer.address);
            expect(buyEvent?.args.amount).to.be.equal(buyerTokenBalance); 
        });

        it("Get AmountToPurchase", async function () {
            const { launchPad } = await loadFixture(deployBondingCurve);
        
            const [owner, buyer] = await hre.ethers.getSigners();

            console.log(`contract owner ${owner.address}`)

            const tx = await launchPad.connect(owner).createBioDiversityERC404Token("MyToken", "MT", ethers.parseEther("1000000000"));
            const receipt = await tx.wait();
            
            const event = receipt?.logs
                        .map(log => launchPad.interface.parseLog(log))
                        .find(e => e?.name === "ContractDeployed");
        
            const contractAddress = event?.args.contractAddress;
        
            expect(event?.args.deployedBy).to.equals(owner.address)    
            expect(await launchPad.getLaunchedContractCount()).to.equals(1);

             // Start the token sale
             await launchPad.startSale(contractAddress);

             const token = await hre.ethers.getContractAt("IERC20", contractAddress);
             const totalSupply = await token.totalSupply();       
 
             console.log(`TotalSupply: ${hre.ethers.formatUnits(totalSupply, 18)}`)
             
             // Buy tokens with 1 ETH
             const buyTx = await launchPad.connect(buyer).buyToken(contractAddress, { value: ethers.parseEther("1.1"),});
             const buyReceipt = await buyTx.wait();
 
             // Assert event emitted
             const buyEvent = buyReceipt?.logs
             .map(log => launchPad.interface.parseLog(log))
             .find(e => e?.name === "TokensPurchased");

            const amount = await launchPad.calculatePurchaseBalance(contractAddress, ethers.parseEther("0.01"));

            console.log(`Amount To Purhcase: ${parseFloat(hre.ethers.formatEther(amount))}`);
            
        });

        it("verify sell token", async function () {
            const { launchPad} = await loadFixture(deployBondingCurve);
            const [owner, buyer] = await hre.ethers.getSigners();
            
            const balance = await hre.ethers.provider.getBalance(owner.address);
        
            console.log(`${buyer.address} has a wallet balance: ${balance}`)

            const tx = await launchPad.connect(owner).createBioDiversityERC404Token("MyToken", "MT", ethers.parseEther("1000000000"));
            const receipt = await tx.wait();
            
            const event = receipt?.logs
                        .map(log => launchPad.interface.parseLog(log))
                        .find(e => e?.name === "ContractDeployed");
            
            const contractAddress = event?.args.contractAddress;
            
             // Start the token sale
            await launchPad.startSale(contractAddress);

            const token = await hre.ethers.getContractAt("IERC20", contractAddress);
            const totalSupply = await token.totalSupply();       

            console.log(`TotalSupply: ${hre.ethers.formatUnits(totalSupply, 18)}`)
            
            // Buy tokens with 1 ETH
            const buyTx = await launchPad.connect(buyer).buyToken(contractAddress, { value: ethers.parseEther("0.01"),});
            const buyReceipt = await buyTx.wait();

            // Assert event emitted
            const buyEvent = buyReceipt?.logs
            .map(log => launchPad.interface.parseLog(log))
            .find(e => e?.name === "TokensPurchased");

            const afterTokenBalance = await token.balanceOf(await launchPad.getAddress());
            const buyerTokenBalance = await token.balanceOf(buyer.address);

            console.log(`launchPad: ${await launchPad.getAddress()}, token balance: ${hre.ethers.formatUnits(afterTokenBalance, 18)}`)
            console.log(`buyer: ${buyer.address}, token balance: ${hre.ethers.formatUnits(buyerTokenBalance, 18)}`)
            
            expect(buyEvent?.args.buyer).to.equal(buyer.address);
            expect(buyEvent?.args.amount).to.be.equal(buyerTokenBalance); 

            
            const sellAmount = 100_000n
            await token.connect(buyer).approve(await launchPad.getAddress(), sellAmount);

            const sellTx = await launchPad.connect(buyer).sellToken(contractAddress, sellAmount);
            const sellReceipt = await sellTx.wait();

            const afterTokenBalance2 = await token.balanceOf(await launchPad.getAddress());
            const buyerTokenBalance2 = await token.balanceOf(buyer.address);

            console.log(`launchPad: ${await launchPad.getAddress()}, token balance: ${hre.ethers.formatUnits(afterTokenBalance2, 18)}`)
            console.log(`buyer: ${buyer.address}, token balance: ${hre.ethers.formatUnits(buyerTokenBalance2, 18)}`)

            expect(afterTokenBalance2).to.be.equal(afterTokenBalance + sellAmount); 

        });

    });
    
});
