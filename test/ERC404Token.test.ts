import { expect } from "chai";
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { ethers } from "hardhat";

describe("ERC404Token", function () {
  const initialSupply = ethers.parseEther("800000000");  
  const taxPermil = 50; // 5%
  const defaultMetadataURIs = [
    "https://gateway.pinata.cloud/ipfs/example1.json",
    "https://gateway.pinata.cloud/ipfs/example2.json",
    "https://gateway.pinata.cloud/ipfs/example3.json",
    "https://gateway.pinata.cloud/ipfs/example4.json",
    "https://gateway.pinata.cloud/ipfs/example5.json"
  ];

  async function deployERC404Fixture() {
    const [owner, user, treasury] = await hre.ethers.getSigners();
    
    const erc404 = await hre.ethers.deployContract("ERC404Token", [
      "TestToken",
      "TT",
      initialSupply,
      owner.address,
      owner.address,
      treasury.address,
      taxPermil,
      "Color",
      ["Green", "Blue", "Purple", "Orange", "Red"],
      defaultMetadataURIs
    ]);

    return { erc404, owner, user, treasury };
  }

  describe("Deployment", function () {
    it("올바른 초기화 파라미터 설정", async function () {
      const { erc404, owner, treasury } = await loadFixture(deployERC404Fixture);
      
      expect(await erc404.name()).to.equal("TestToken");
      expect(await erc404.symbol()).to.equal("TT");
      expect(await erc404.erc20BalanceOf(owner.address)).to.equal(initialSupply);
      expect(await erc404.owner()).to.equal(owner.address);
  });
  });

  describe("ERC20/ERC721 기능", function () {
    it("ERC20 전송 시 NFT 자동 생성/소각", async function () {
      const { erc404, owner, user } = await loadFixture(deployERC404Fixture);
      const transferAmount = ethers.parseEther("2000000");
      
      await erc404.transfer(user.address, transferAmount);
      //expect(await erc404.erc20BalanceOf(user.address)).to.equal(transferAmount); // 세금으로 인한 변동
      const ownedTokens = await erc404.owned(user.address);
      const ownedTokenId = ownedTokens[0];
      expect(await erc404.ownerOf(ownedTokenId)).to.equal(user.address); // NFT 생성 확인
      
      const balanceWithTax = await erc404.erc20BalanceOf(user.address);
      await erc404.connect(user).transfer(owner.address, balanceWithTax);
      await expect(erc404.ownerOf(ownedTokenId)).to.be.reverted; // NFT 소각 확인
    });

    it("면제 계정은 NFT 생성 없이 전송 가능", async function () {
      const { erc404, owner, user } = await loadFixture(deployERC404Fixture);
      await erc404.setERC721TransferExempt(user.address, true);
      
      await erc404.transfer(user.address, ethers.parseEther("2000000"));
      const ownedTokens = await erc404.owned(user.address);
      //console.log(ownedTokens.length);
      expect(ownedTokens.length).to.equal(0); // NFT 생성 안 됨 - 보유 Token 0개
    });
  });

  describe("세금 메커니즘", function () {
    it("전송 시 5% 세금 공제", async function () {
      const { erc404, owner, user, treasury } = await loadFixture(deployERC404Fixture);
      const transferAmount = ethers.parseEther("100");
      const expectedFee = transferAmount * BigInt(taxPermil) / 1000n;
      
      const initialTreasuryBalance = await erc404.erc20BalanceOf(treasury.address);
      await erc404.transfer(user.address, transferAmount);
      
      expect(await erc404.erc20BalanceOf(user.address)).to.equal(transferAmount - expectedFee);
      expect(await erc404.erc20BalanceOf(treasury.address)).to.equal(initialTreasuryBalance + expectedFee);
    });
  });

  describe("메타데이터 기능", function () {
    it("희귀도에 따른 Pinata 메타데이터 URI 반환", async function () {
      const { erc404, owner, user } = await loadFixture(deployERC404Fixture);
      await erc404.transfer(user.address, ethers.parseEther("2000000"));

      const ownedTokens = await erc404.owned(user.address);
      const ownedTokenId = ownedTokens[0];
      const tokenURI = await erc404.tokenURI(ownedTokenId);
      expect(defaultMetadataURIs).to.include(tokenURI);
    });

    it("메타데이터 URI 재설정 시 신규 URI 사용", async function () {
      const { erc404, owner, user } = await loadFixture(deployERC404Fixture);
      await erc404.transfer(user.address, ethers.parseEther("2000000"));

      const ownedTokens = await erc404.owned(user.address);
      const newMetadataURIs = [
        "https://gateway.pinata.cloud/ipfs/new1.json",
        "https://gateway.pinata.cloud/ipfs/new2.json",
        "https://gateway.pinata.cloud/ipfs/new3.json",
        "https://gateway.pinata.cloud/ipfs/new4.json",
        "https://gateway.pinata.cloud/ipfs/new5.json"
      ];

      await erc404.setMetadataURIs(
        newMetadataURIs[0],
        newMetadataURIs[1],
        newMetadataURIs[2],
        newMetadataURIs[3],
        newMetadataURIs[4]
      );

      const tokenURI = await erc404.tokenURI(ownedTokens[0]);
      expect(newMetadataURIs).to.include(tokenURI);
    });
  });

  describe("접근 제어", function () {
    it("소유자만 설정 변경 가능", async function () {
      const { erc404, user } = await loadFixture(deployERC404Fixture);
      
      await expect(erc404.connect(user).transferOwnership(user))
        .to.be.reverted;
    });
  });
});
