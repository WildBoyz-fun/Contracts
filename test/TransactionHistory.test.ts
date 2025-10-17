import { expect } from "chai";
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { ethers } from "hardhat";
import { TokenParams } from "./params/TokenParams";

describe("LaunchPad - Transaction History", function () {
    let params: TokenParams;

    async function initParams() {
        const [owner, buyer1, buyer2] = await hre.ethers.getSigners();
        
        const bondingCurve = await hre.ethers.deployContract("BondingCurve");
        const ownerGroupContract = await hre.ethers.deployContract("OwnerGroupContract", [[owner.address]]);
        const launchPadTokenTreasury = await hre.ethers.deployContract("LaunchPanTokenTreasury", [await ownerGroupContract.getAddress()]);
        
        const launchPad = await hre.ethers.deployContract("LaunchPad", [await launchPadTokenTreasury.getAddress(), await bondingCurve.getAddress(), await ownerGroupContract.getAddress()]);

        params = new TokenParams();
        return { launchPad, params, owner, buyer1, buyer2 };
    }

    describe("Token Transaction History", function () {
        it("should record transaction history when buying tokens", async function () {
            const { launchPad, params, owner, buyer1, buyer2 } = await loadFixture(initParams);

            // Create a token
            const createTx = await launchPad.createBioDiversityERC404Token(
                params.tokenTreasuryAddress,
                params.totalSupply,
                params.symbol,
                params.name,
                params.taxPermil,
                params.traitType,
                params.traitValues,
                params.images,
                { value: ethers.parseEther("0.001") }
            );
            const createReceipt = await createTx.wait();
            
            const createEvent = createReceipt?.logs
                .map(log => launchPad.interface.parseLog(log))
                .find(e => e?.name === "ContractDeployed");
            
            const tokenAddress = createEvent?.args.contractAddress;

            console.log(`Created token at address: ${tokenAddress}`);

            // Buyer1 buys tokens with 1 ETH
            console.log("\n=== Buyer1 purchasing 1 ETH worth of tokens ===");
            const buyTx1 = await launchPad.connect(buyer1).buyToken(tokenAddress, { 
                value: ethers.parseEther("1") 
            });
            await buyTx1.wait();

            // Buyer2 buys tokens with 0.5 ETH
            console.log("\n=== Buyer2 purchasing 0.5 ETH worth of tokens ===");
            const buyTx2 = await launchPad.connect(buyer2).buyToken(tokenAddress, { 
                value: ethers.parseEther("0.5") 
            });
            await buyTx2.wait();

            // Buyer1 buys more tokens with 2 ETH
            console.log("\n=== Buyer1 purchasing another 2 ETH worth of tokens ===");
            const buyTx3 = await launchPad.connect(buyer1).buyToken(tokenAddress, { 
                value: ethers.parseEther("2") 
            });
            await buyTx3.wait();

            // Get transaction history for the token
            console.log("\n=== Getting Token Transaction History ===");
            const tokenHistory = await launchPad.getTokenTransactionHistory(tokenAddress);
            
            console.log(`Total transactions for token: ${tokenHistory.length}`);
            
            // Display each transaction
            for (let i = 0; i < tokenHistory.length; i++) {
                const tx = tokenHistory[i];
                console.log(`\n--- Transaction ${i + 1} ---`);
                console.log(`Timestamp: ${new Date(Number(tx.timestamp) * 1000).toISOString()}`);
                console.log(`User: ${tx.user}`);
                console.log(`Token Address: ${tx.tokenAddress}`);
                console.log(`Transaction Type: ${tx.transactionType}`);
                console.log(`ETH Amount: ${ethers.formatEther(tx.ethAmount)} ETH`);
                console.log(`Token Amount: ${ethers.formatEther(tx.tokenAmount)} tokens`);
                console.log(`Price Per Token: ${ethers.formatEther(tx.pricePerToken)} ETH per token`);
                console.log(`Total Supply After: ${ethers.formatEther(tx.totalSupplyAfter)} tokens`);
                console.log(`ETH Balance After: ${ethers.formatEther(tx.ethBalanceAfter)} ETH`);
                console.log(`Block Number: ${tx.blockNumber}`);
            }

            // Get transaction history for buyer1
            console.log("\n=== Getting Buyer1 Transaction History ===");
            const buyer1History = await launchPad.getUserTransactionHistory(buyer1.address);
            
            console.log(`Total transactions for buyer1: ${buyer1History.length}`);
            
            for (let i = 0; i < buyer1History.length; i++) {
                const tx = buyer1History[i];
                console.log(`\n--- Buyer1 Transaction ${i + 1} ---`);
                console.log(`ETH Amount: ${ethers.formatEther(tx.ethAmount)} ETH`);
                console.log(`Token Amount: ${ethers.formatEther(tx.tokenAmount)} tokens`);
                console.log(`Transaction Type: ${tx.transactionType}`);
            }

            // Get transaction history for buyer2
            console.log("\n=== Getting Buyer2 Transaction History ===");
            const buyer2History = await launchPad.getUserTransactionHistory(buyer2.address);
            
            console.log(`Total transactions for buyer2: ${buyer2History.length}`);
            
            for (let i = 0; i < buyer2History.length; i++) {
                const tx = buyer2History[i];
                console.log(`\n--- Buyer2 Transaction ${i + 1} ---`);
                console.log(`ETH Amount: ${ethers.formatEther(tx.ethAmount)} ETH`);
                console.log(`Token Amount: ${ethers.formatEther(tx.tokenAmount)} tokens`);
                console.log(`Transaction Type: ${tx.transactionType}`);
            }

            // Get recent transactions
            console.log("\n=== Getting Recent Transactions (Last 5) ===");
            const recentTransactions = await launchPad.getRecentTransactions(5);
            
            console.log(`Recent transactions count: ${recentTransactions.length}`);
            
            for (let i = 0; i < recentTransactions.length; i++) {
                const tx = recentTransactions[i];
                console.log(`\n--- Recent Transaction ${i + 1} ---`);
                console.log(`User: ${tx.user}`);
                console.log(`ETH Amount: ${ethers.formatEther(tx.ethAmount)} ETH`);
                console.log(`Token Amount: ${ethers.formatEther(tx.tokenAmount)} tokens`);
                console.log(`Transaction Type: ${tx.transactionType}`);
            }

            // Verify expectations
            expect(tokenHistory.length).to.equal(3);
            expect(buyer1History.length).to.equal(2);
            expect(buyer2History.length).to.equal(1);

            // Check first transaction (buyer1's first purchase)
            expect(tokenHistory[0].user).to.equal(buyer1.address);
            expect(tokenHistory[0].transactionType).to.equal("BUY");
            expect(tokenHistory[0].ethAmount).to.equal(ethers.parseEther("1"));

            // Check second transaction (buyer2's purchase) 
            expect(tokenHistory[1].user).to.equal(buyer2.address);
            expect(tokenHistory[1].transactionType).to.equal("BUY");
            expect(tokenHistory[1].ethAmount).to.equal(ethers.parseEther("0.5"));

            // Check third transaction (buyer1's second purchase)
            expect(tokenHistory[2].user).to.equal(buyer1.address);
            expect(tokenHistory[2].transactionType).to.equal("BUY");
            expect(tokenHistory[2].ethAmount).to.equal(ethers.parseEther("2"));

            console.log("\n=== All tests passed! ===");
        });

        it("should record sell transactions in history", async function () {
            const { launchPad, params, owner, buyer1 } = await loadFixture(initParams);

            // Create a token
            const createTx = await launchPad.createBioDiversityERC404Token(
                params.tokenTreasuryAddress,
                params.totalSupply,
                params.symbol,
                params.name,
                params.taxPermil,
                params.traitType,
                params.traitValues,
                params.images,
                { value: ethers.parseEther("0.001") }
            );
            const createReceipt = await createTx.wait();
            
            const createEvent = createReceipt?.logs
                .map(log => launchPad.interface.parseLog(log))
                .find(e => e?.name === "ContractDeployed");
            
            const tokenAddress = createEvent?.args.contractAddress;

            // Buy tokens first
            console.log("\n=== Buyer1 purchasing tokens ===");
            await launchPad.connect(buyer1).buyToken(tokenAddress, { 
                value: ethers.parseEther("1") 
            });

            // Get ERC404 contract instance
            const erc404Token = await hre.ethers.getContractAt("IERC404", tokenAddress);
            
            // Check buyer's balance before selling
            const buyerBalance = await erc404Token.erc20BalanceOf(buyer1.address);
            console.log(`Buyer1 token balance: ${ethers.formatEther(buyerBalance)} tokens`);

            // Approve LaunchPad to spend buyer's tokens
            const sellAmount = ethers.parseEther("100000"); // 100k tokens
            await erc404Token.connect(buyer1).approve(await launchPad.getAddress(), sellAmount);

            // Sell tokens
            console.log("\n=== Buyer1 selling tokens ===");
            await launchPad.connect(buyer1).sellToken(tokenAddress, sellAmount);

            // Get transaction history
            const tokenHistory = await launchPad.getTokenTransactionHistory(tokenAddress);
            const buyer1History = await launchPad.getUserTransactionHistory(buyer1.address);

            console.log(`\nTotal token transactions: ${tokenHistory.length}`);
            console.log(`Total buyer1 transactions: ${buyer1History.length}`);

            // Display transaction history
            for (let i = 0; i < tokenHistory.length; i++) {
                const tx = tokenHistory[i];
                console.log(`\n--- Transaction ${i + 1} ---`);
                console.log(`Transaction Type: ${tx.transactionType}`);
                console.log(`ETH Amount: ${ethers.formatEther(tx.ethAmount)} ETH`);
                console.log(`Token Amount: ${ethers.formatEther(tx.tokenAmount)} tokens`);
            }

            // Verify expectations
            expect(tokenHistory.length).to.equal(2); // 1 buy + 1 sell
            expect(buyer1History.length).to.equal(2); // 1 buy + 1 sell

            // Check buy transaction
            expect(tokenHistory[0].transactionType).to.equal("BUY");
            expect(tokenHistory[0].ethAmount).to.equal(ethers.parseEther("1"));

            // Check sell transaction  
            expect(tokenHistory[1].transactionType).to.equal("SELL");
            expect(tokenHistory[1].tokenAmount).to.equal(sellAmount);

            console.log("\n=== Sell transaction test passed! ===");
        });
    });
});
