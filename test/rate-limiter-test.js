const { web3 } = require("hardhat");
const { expect } = require("chai");
const { ethers } = require("hardhat");

var ToBig = (x) => ethers.BigNumber.from(x);

describe("RateLimiter Test", function () {
  it("simple", async function () {
    const RateLimiterFactory = await ethers.getContractFactory("RateLimiterTest");
    const rl = await RateLimiterFactory.deploy(100);
    await rl.deployed();

    await rl.consume("10000000000000000000"); // 10
    expect(await rl.getRate()).to.equal("10");

    await rl.consume("10000000000000000000"); // 10
    expect(await rl.getRate()).to.equal("20");

    await expect(rl.consume("90000000000000000000")).to.be.reverted; // 90
    expect(await rl.getRate()).to.equal("20");

    await rl.setTimestamp(3600);
    await rl.consume("10000000000000000000"); // 10
    expect(await rl.getRate()).to.equal("30");
  });
});
