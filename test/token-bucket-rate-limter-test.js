const { web3 } = require("hardhat");
const { expect } = require("chai");
const { ethers } = require("hardhat");

var ToBig = (x) => ethers.BigNumber.from(x);

describe("TokenBucket Test", function () {
  it("simple", async function () {
    const RateLimiterFactory = await ethers.getContractFactory("TokenBucketRateLimiterTest");
    const rl = await RateLimiterFactory.deploy("1000000000000000000", "20000000000000000000"); // refill 1 token per second with 20 tokens cap
    await rl.deployed();

    await rl.consume("10000000000000000000"); // 10
    expect(await rl.getRate()).to.equal("10000000000000000000");

    await rl.consume("10000000000000000000"); // 10
    expect(await rl.getRate()).to.equal("20000000000000000000");
  });

  it("complex", async function () {
    const RateLimiterFactory = await ethers.getContractFactory("TokenBucketRateLimiterTest");
    const rl = await RateLimiterFactory.deploy("1000000000000000000", "100000000000000000000"); // refill 1 token per second with 100 tokens cap
    await rl.deployed();

    await rl.consume("10000000000000000000"); // 10
    expect(await rl.getRate()).to.equal("10000000000000000000");

    await rl.consume("10000000000000000000"); // 10
    expect(await rl.getRate()).to.equal("20000000000000000000");

    await expect(rl.consume("90000000000000000000")).to.be.reverted; // 90
    expect(await rl.getRate()).to.equal("20000000000000000000");

    await rl.consume("10000000000000000000"); // 10
    expect(await rl.getRate()).to.equal("30000000000000000000");

    await rl.consume("20000000000000000000"); // 20
    expect(await rl.getRate()).to.equal("50000000000000000000");

    await rl.consume("50000000000000000000"); // 50
    expect(await rl.getRate()).to.equal("100000000000000000000");

    await expect(rl.consume("1")).to.be.reverted;

    await rl.setTimestamp(20); // will expire 20
    await rl.consume("1");
    expect(await rl.getRate()).to.equal("80000000000000000001");
  });

  it("expire one", async function () {
    const RateLimiterFactory = await ethers.getContractFactory("TokenBucketRateLimiterTest");
    const rl = await RateLimiterFactory.deploy("1000000000000000000", "100000000000000000000"); // 4 hours with 1 hour per bin
    await rl.deployed();

    await rl.consume("60000000000000000000"); // 60
    expect(await rl.getRate()).to.equal("60000000000000000000");

    await rl.setTimestamp(60);
    await rl.consume("70000000000000000000"); // round to 70
    expect(await rl.getRate()).to.equal("70000000000000000000");
  });

  it("expire multiple", async function () {
    const RateLimiterFactory = await ethers.getContractFactory("TokenBucketRateLimiterTest");
    const rl = await RateLimiterFactory.deploy("1000000000000000000", "100000000000000000000"); // 4 hours with 1 hour per bin
    await rl.deployed();

    await rl.consume("60000000000000000000"); // 60
    expect(await rl.getRate()).to.equal("60000000000000000000");

    await rl.setTimestamp(30);
    await rl.consume("70000000000000000000"); // round to 70
    expect(await rl.getRate()).to.equal("100000000000000000000");

    await rl.setTimestamp(40);
    await expect(rl.consume("20000000000000000000")).to.be.reverted;

    await rl.setTimestamp(50);
    await rl.consume("20000000000000000000"); // round to 70
    expect(await rl.getRate()).to.equal("100000000000000000000");
  });
});
