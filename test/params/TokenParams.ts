import { ethers } from "hardhat";

export class TokenParams {
  tokenTreasuryAddress: string;
  totalSupply: bigint;
  symbol: string;
  name: string;
  taxPermil: bigint;
  imageURI: string;
  traitType: string;
  traitValues: [string, string, string, string, string];
  images: [string, string, string, string, string];
  description: string;

  constructor() {
    this.tokenTreasuryAddress = ethers.Wallet.createRandom().address;
    this.totalSupply = ethers.parseEther("1000000000");
    this.symbol = "MT";
    this.name = "MyToken";
    this.taxPermil = 50n;
    this.imageURI = "test-image-uri";
    this.traitType = "Green";
    this.traitValues = ["Green", "Blue", "Purple", "Orange", "Red"];
    this.images = ["img1", "img2", "img3", "img4", "img5"];
    this.description = "Test token description";
  }
}
