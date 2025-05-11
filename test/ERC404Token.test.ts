import { expect } from "chai";
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { ethers } from "hardhat";

describe("ERC404Token", function () {
  const initialSupply = "1000000";
  const initialToken = ethers.parseEther(initialSupply);  
  const taxPermil = 50; // 5%

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
      "https://example.com/",
      "Color",
      ["Green", "Blue", "Purple", "Orange", "Red"],
      ["1.gif", "2.gif", "3.gif", "4.gif", "5.gif"]
    ]);

    return { erc404, owner, user, treasury };
  }

  describe("Deployment", function () {
    it("올바른 초기화 파라미터 설정", async function () {
      const { erc404, owner, treasury } = await loadFixture(deployERC404Fixture);
      
      expect(await erc404.name()).to.equal("TestToken");
      expect(await erc404.symbol()).to.equal("TT");
      expect(await erc404.erc20BalanceOf(owner.address)).to.equal(initialToken);
      expect(await erc404.owner()).to.equal(owner.address);
      expect(await erc404.dataURI()).to.include("https://example.com/");
    });
  });

  describe("ERC20/ERC721 기능", function () {
    it("ERC20 전송 시 NFT 자동 생성/소각", async function () {
      const { erc404, owner, user } = await loadFixture(deployERC404Fixture);
      const transferAmount = ethers.parseEther("2");
      
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
      
      await erc404.transfer(user.address, ethers.parseEther("1"));
      await expect(erc404.ownerOf(1)).to.be.reverted; // NFT 생성 안 됨
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
    it("토큰 ID 기반 메타데이터 생성", async function () {
      const { erc404, owner } = await loadFixture(deployERC404Fixture);
      await erc404.transfer(owner.address, ethers.parseEther("1"));
      
      const tokenURI = await erc404.tokenURI(1);
      expect(tokenURI).to.include("data:application/json;utf8");
      expect(tokenURI).to.include('"trait_type":"Color"');
    });

    it("이미지 URI 설정 업데이트", async function () {
      const { erc404 } = await loadFixture(deployERC404Fixture);
      await erc404.setDataURI("https://new.example.com/");
      expect(await erc404.dataURI()).to.equal("https://new.example.com/");
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
