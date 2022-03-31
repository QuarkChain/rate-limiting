const { web3 } = require("hardhat");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { defaultAbiCoder } = require("ethers/lib/utils");

var ToBig = (x) => ethers.BigNumber.from(x);

describe("RateLimiter Test", function () {
  it("simple", async function () {
    const RateLimiterFactory = await ethers.getContractFactory("RateLimiterTest");
    const rl = await RateLimiterFactory.deploy(100);
    await rl.deployed();

    await rl.consume(10 * 1e18);
    expect(await rl.getRate()).to.eql(100);
  });
});
