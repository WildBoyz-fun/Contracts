import { expect } from "chai"
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { ethers } from "hardhat";
import { LaunchPanTokenTreasury__factory } from "../typechain-types";

import { TokenParams } from "./params/TokenParams";

describe("LaunchPad", function () {
    let params: TokenParams;

    async function initParams() {
        const [owner] = await hre.ethers.getSigners();
        
        const bondingCurve = await hre.ethers.deployContract("BondingCurve")
        const ownerGroupContract = await hre.ethers.deployContract("OwnerGroupContract", [[owner.address]])
        const launchPadTokenTreasury = await hre.ethers.deployContract("LaunchPanTokenTreasury", [await ownerGroupContract.getAddress()])
        
        const launchPad = await hre.ethers.deployContract("LaunchPad", [await launchPadTokenTreasury.getAddress(), await bondingCurve.getAddress(), await ownerGroupContract.getAddress()])

        params = new TokenParams();
        return { launchPad, params };
    }

    describe("Contract Deploy And Status Check", function () {
        it("contract must be deployed before checking status", async function () {
            const { launchPad, params} = await loadFixture(initParams);
        
            const fakeContractAddress = ethers.Wallet.createRandom().address;
            
            await expect(launchPad.getContractSaleStatus(fakeContractAddress)).to.be.revertedWith("CND");
        });

        it("contract is deployed. Checking Owner and Contract is On Sale", async function () {
            const { launchPad, params } = await loadFixture(initParams);
        
            const [owner] = await hre.ethers.getSigners();

            console.log(`contract owner ${owner.address}`)
    
            const tx = await launchPad.createBioDiversityERC404Token(params.tokenTreasuryAddress,
                params.totalSupply,
                params.symbol,
                params.name,
                params.taxPermil,
                params.imageURI,
                params.traitType,
                params.traitValues,
                params.images
            );
            const receipt = await tx.wait();
            
            const event = receipt?.logs
                        .map(log => launchPad.interface.parseLog(log))
                        .find(e => e?.name === "ContractDeployed");
            
            const contractAddress = event?.args.contractAddress;
            
            expect(event?.args.deployedBy).to.equals(owner.address);
            expect(await launchPad.getContractSaleStatus(contractAddress)).to.equals(true);
        });

        it("contract is deployed. Checking Owner and Contract is On Sale", async function () {
            const { launchPad } = await loadFixture(initParams);
        
            const [owner] = await hre.ethers.getSigners();

            console.log(`contract owner ${owner.address}`)

            const tx = await launchPad.createBioDiversityERC404Token(params.tokenTreasuryAddress,
                params.totalSupply,
                params.symbol,
                params.name,
                params.taxPermil,
                params.imageURI,
                params.traitType,
                params.traitValues,
                params.images
            );
            const receipt = await tx.wait();
            
            const event = receipt?.logs
                        .map(log => launchPad.interface.parseLog(log))
                        .find(e => e?.name === "ContractDeployed");
            
            const contractAddress = event?.args.contractAddress;
            
            expect(event?.args.deployedBy).to.equals(owner.address);

            expect(await launchPad.getContractSaleStatus(contractAddress)).to.equals(true);
        });


        it("contract is deployed. Contract Sale is halted", async function () {
            const { launchPad } = await loadFixture(initParams);
        
            const [owner] = await hre.ethers.getSigners();

            console.log(`contract owner ${owner.address}`)

            const tx = await launchPad.createBioDiversityERC404Token(params.tokenTreasuryAddress,
                params.totalSupply,
                params.symbol,
                params.name,
                params.taxPermil,
                params.imageURI,
                params.traitType,
                params.traitValues,
                params.images
            );
            const receipt = await tx.wait();
            
            const event = receipt?.logs
                        .map(log => launchPad.interface.parseLog(log))
                        .find(e => e?.name === "ContractDeployed");
            
            const contractAddress = event?.args.contractAddress;
            
            expect(event?.args.deployedBy).to.equals(owner.address);
            

            expect(await launchPad.getContractSaleStatus(contractAddress)).to.equals(true);
            await launchPad.connect(owner).changeContractSaleStatus(contractAddress);
            expect(await launchPad.getContractSaleStatus(contractAddress)).to.equals(false);
        });

        it("contract is deployed. Contract Count 1", async function () {
            const { launchPad } = await loadFixture(initParams);
        
            const [owner] = await hre.ethers.getSigners();

            console.log(`contract owner ${owner.address}`)

            const tx = await launchPad.createBioDiversityERC404Token(params.tokenTreasuryAddress,
                params.totalSupply,
                params.symbol,
                params.name,
                params.taxPermil,
                params.imageURI,
                params.traitType,
                params.traitValues,
                params.images
            );
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
            const { launchPad} = await loadFixture(initParams);
            const [owner, buyer] = await hre.ethers.getSigners();
            
            const balance = await hre.ethers.provider.getBalance(owner.address);
        
            console.log(`${buyer.address} has a wallet balance: ${balance}`)

            const tx = await launchPad.createBioDiversityERC404Token(params.tokenTreasuryAddress,
                params.totalSupply,
                params.symbol,
                params.name,
                params.taxPermil,
                params.imageURI,
                params.traitType,
                params.traitValues,
                params.images
            );
            const receipt = await tx.wait();
            
            const event = receipt?.logs
                        .map(log => launchPad.interface.parseLog(log))
                        .find(e => e?.name === "ContractDeployed");
            
            const contractAddress = event?.args.contractAddress;

            // const sendAmount = hre.ethers.parseEther("1");
            
            // Send ETH to the contract from otherAccount
            // const ethTx = await owner.sendTransaction({
            //     to: contractAddress,
            //     value: sendAmount
            // });
            // await ethTx.wait();

            // const ethBalance = await ethers.provider.getBalance(contractAddress);
            // console.log(`Contract(${contractAddress}) ETH Balance: ${ethBalance}`)
        
            const erc404Token = await hre.ethers.getContractAt("IERC404", contractAddress);
            const totalSupply = await erc404Token.totalSupply();       

            console.log(`erc404Token TotalSupply: ${totalSupply}`)
        
            const launchPadTokenBalance = await erc404Token.erc20BalanceOf(await launchPad.getAddress());
            const buyerTokenBalance = await erc404Token.erc20BalanceOf(buyer.address);
            console.log(`[Before Token Purchased] LaunchPad tokenBalance: ${launchPadTokenBalance}`);
            console.log(`[Before Token Purchased] buyerTokenBalance tokenBalance: ${buyerTokenBalance}`);
            
            // Buy tokens with 1 ETH
            const buyTx = await launchPad.connect(buyer).buyToken(contractAddress, { value: ethers.parseEther("1"),});
            const buyReceipt = await buyTx.wait();
            
            // Assert event emitted
            const buyEvent = buyReceipt?.logs
            .map(log => launchPad.interface.parseLog(log))
            .find(e => e?.name === "TokensPurchased");

            const launchPadTokenBalance2 = await erc404Token.erc20BalanceOf(await launchPad.getAddress());
            const buyerTokenBalance2 = await erc404Token.erc20BalanceOf(buyer.address);

            console.log(`[After Token Purchased] launchPad: ${await launchPad.getAddress()}, token balance: ${launchPadTokenBalance2}`)
            console.log(`[After Token Purchased] buyer: ${buyer.address}, token balance: ${buyerTokenBalance2}`)
            
            expect(buyEvent?.args.buyer).to.equal(buyer.address);
            expect(buyEvent?.args.amount).to.be.equal(totalSupply - launchPadTokenBalance2); 
        });

        it("verify sell token", async function () {
            const { launchPad} = await loadFixture(initParams);
            const [owner, buyer] = await hre.ethers.getSigners();
            
            const balance = await hre.ethers.provider.getBalance(owner.address);
        
            console.log(`${buyer.address} has a wallet balance: ${balance}`)

            const tx = await launchPad.createBioDiversityERC404Token(params.tokenTreasuryAddress,
                params.totalSupply,
                params.symbol,
                params.name,
                params.taxPermil,
                params.imageURI,
                params.traitType,
                params.traitValues,
                params.images
            );
            const receipt = await tx.wait();
            
            const event = receipt?.logs
                        .map(log => launchPad.interface.parseLog(log))
                        .find(e => e?.name === "ContractDeployed");
            
            const contractAddress = event?.args.contractAddress;

            const erc404Token = await hre.ethers.getContractAt("IERC404", contractAddress);
            const totalSupply = await erc404Token.totalSupply();       

            console.log(`erc404Token TotalSupply: ${hre.ethers.formatUnits(totalSupply, 18)}`)
            
            // Buy tokens with 1 ETH
            const buyTx = await launchPad.connect(buyer).buyToken(contractAddress, { value: ethers.parseEther("1"),});
            const buyReceipt = await buyTx.wait();

            // Assert event emitted
            const buyEvent = buyReceipt?.logs
            .map(log => launchPad.interface.parseLog(log))
            .find(e => e?.name === "TokensPurchased");
        
            const launchPadTokenBalance = await erc404Token.erc20BalanceOf(await launchPad.getAddress());
            const buyerTokenBalance = await erc404Token.erc20BalanceOf(buyer.address);
            console.log(`[Before Token Sell] LaunchPad tokenBalance: ${launchPadTokenBalance}`);
            console.log(`[Before Token Sell] buyerTokenBalance tokenBalance: ${buyerTokenBalance}`);
            
            expect(buyEvent?.args.buyer).to.equal(buyer.address);
            expect(buyEvent?.args.amount).to.be.equal(totalSupply - launchPadTokenBalance); 

            const sellAmount = 100_000n
            await erc404Token.connect(buyer).approve(await launchPad.getAddress(), sellAmount);

            const sellTx = await launchPad.connect(buyer).sellToken(contractAddress, sellAmount);
            const sellReceipt = await sellTx.wait();

    
            const sellEvent = sellReceipt?.logs
            .map(log => launchPad.interface.parseLog(log))
            .find(e => e?.name === "TokenSold");

            const launchPadTokenBalance2 = await erc404Token.erc20BalanceOf(await launchPad.getAddress());
            const buyerTokenBalance2 = await erc404Token.erc20BalanceOf(buyer.address);

            console.log(`[After Token Sell] launchPad: ${await launchPad.getAddress()}, token balance: ${launchPadTokenBalance2}`)
            console.log(`[After Token Sell] buyer: ${buyer.address}, token balance: ${buyerTokenBalance2}`)

            console.log(`contract ETH balance ${await launchPad.getContractEthBalance(contractAddress)}`);
            console.log(`contract TotalSupply balance ${await launchPad.getContractTotalSupplyBalance(contractAddress)}`);

            expect(sellEvent?.args.amount).to.be.equal(sellAmount); 

        });

        it("Get AmountToPurchase", async function () {
            const { launchPad } = await loadFixture(initParams);
        
            const [owner, buyer] = await hre.ethers.getSigners();

            console.log(`contract owner ${owner.address}`)

            const tx = await launchPad.createBioDiversityERC404Token(params.tokenTreasuryAddress,
                params.totalSupply,
                params.symbol,
                params.name,
                params.taxPermil,
                params.imageURI,
                params.traitType,
                params.traitValues,
                params.images
            );
            const receipt = await tx.wait();
            
            const event = receipt?.logs
                        .map(log => launchPad.interface.parseLog(log))
                        .find(e => e?.name === "ContractDeployed");
        
            const contractAddress = event?.args.contractAddress;
        
            expect(event?.args.deployedBy).to.equals(owner.address)    
            expect(await launchPad.getLaunchedContractCount()).to.equals(1);

             const erc404Token = await hre.ethers.getContractAt("IERC404", contractAddress);
             const totalSupply = await erc404Token.totalSupply();       
 
             console.log(`TotalSupply: ${hre.ethers.formatUnits(totalSupply, 18)}`)
             
             // Buy tokens with 1 ETH
             const buyTx = await launchPad.connect(buyer).buyToken(contractAddress, { value: ethers.parseEther("1"),});
             const buyReceipt = await buyTx.wait();
 
             // Assert event emitted
             const buyEvent = buyReceipt?.logs
             .map(log => launchPad.interface.parseLog(log))
             .find(e => e?.name === "TokensPurchased");

            const amount = await launchPad.calculatePurchaseBalance(contractAddress, ethers.parseEther("0.01"));

            console.log(`Amount To Purhcase: ${parseFloat(hre.ethers.formatEther(amount))}`);
            
        });



    });
    
});
