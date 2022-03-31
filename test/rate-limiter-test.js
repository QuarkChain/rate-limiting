const { web3 } = require("hardhat");
const { expect } = require("chai");
const { ethers } = require("hardhat");

var ToBig = (x) => ethers.BigNumber.from(x);

describe("RateLimiter Test", function () {
  it("simple", async function () {
    const RateLimiterFactory = await ethers.getContractFactory("RateLimiterTest");
    const rl = await RateLimiterFactory.deploy(4, 3600, 100);  // 4 hours with 1 hour per bin
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

  it("simple", async function () {
    const RateLimiterFactory = await ethers.getContractFactory("RateLimiterTest");
    const rl = await RateLimiterFactory.deploy(4, 3600, 100);  // 4 hours with 1 hour per bin
    await rl.deployed();

    await rl.consume("10000000000000000000"); // 10
    expect(await rl.getRate()).to.equal("10");

    await rl.setTimestamp(3600 * 4);
    await rl.consume("20000000000000000000"); // 20
    expect(await rl.getRate()).to.equal("20");

    await rl.setTimestamp(3600 * 12);
    await rl.consume("30000000000000000000"); // 30
    expect(await rl.getRate()).to.equal("30");
  });
});
