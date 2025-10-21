import { ethers } from "hardhat";

export class TokenParams {
  tokenTreasuryAddress: string;
  totalSupply: bigint;
  symbol: string;
  name: string;
  taxPermil: bigint;
  traitType: string;
  traitValues: [string, string, string, string, string];
  mainImage: string;
  metadataURIs: [string, string, string, string, string];

  constructor() {
    this.tokenTreasuryAddress = ethers.Wallet.createRandom().address;
    this.totalSupply = ethers.parseEther("1000000000");
    this.symbol = "MT";
    this.name = "MyToken";
    this.taxPermil = 50n;
    this.traitType = "Green";
    this.traitValues = ["Green", "Blue", "Purple", "Orange", "Red"];
    this.mainImage = "https://example.com/img1.png";
    this.metadataURIs = [
      "https://gateway.pinata.cloud/ipfs/example1.json",
      "https://gateway.pinata.cloud/ipfs/example2.json",
      "https://gateway.pinata.cloud/ipfs/example3.json",
      "https://gateway.pinata.cloud/ipfs/example4.json",
      "https://gateway.pinata.cloud/ipfs/example5.json"
    ];
  }
}
