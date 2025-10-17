import { ethers } from "hardhat";

export class TokenParams {
  tokenTreasuryAddress: string;
  totalSupply: bigint;
  symbol: string;
  name: string;
  taxPermil: bigint;
  traitType: string;
  traitValues: [string, string, string, string, string];
  images: [string, string, string, string, string];

  constructor() {
    this.tokenTreasuryAddress = ethers.Wallet.createRandom().address;
    this.totalSupply = ethers.parseEther("1000000000");
    this.symbol = "MT";
    this.name = "MyToken";
    this.taxPermil = 50n;
    this.traitType = "Green";
    this.traitValues = ["Green", "Blue", "Purple", "Orange", "Red"];
    this.images = [
      "https://example.com/img1.png",
      "https://example.com/img2.png",
      "https://example.com/img3.png",
      "https://example.com/img4.png",
      "https://example.com/img5.png"
    ];
  }
}
