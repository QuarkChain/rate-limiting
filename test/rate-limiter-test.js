const { web3 } = require("hardhat");
const { expect } = require("chai");
const { ethers } = require("hardhat");

var ToBig = (x) => ethers.BigNumber.from(x);

describe("RateLimiter Test", function () {
  it("simple", async function () {
    const RateLimiterFactory = await ethers.getContractFactory("RateLimiterTest");
    const rl = await RateLimiterFactory.deploy(4, 3600, 100); // 4 hours with 1 hour per bin
    await rl.deployed();

    await rl.consume("10000000000000000000"); // 10
    expect(await rl.getRate()).to.equal("10");

    await rl.consume("10000000000000000000"); // 10
    expect(await rl.getRate()).to.equal("20");
  });

  it("complex", async function () {
    const RateLimiterFactory = await ethers.getContractFactory("RateLimiterTest");
    const rl = await RateLimiterFactory.deploy(4, 3600, 100); // 4 hours with 1 hour per bin
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

    await rl.setTimestamp(2 * 3600);
    await rl.consume("20000000000000000000"); // 20
    expect(await rl.getRate()).to.equal("50");

    await rl.setTimestamp(3 * 3600);
    await rl.consume("50000000000000000000"); // 50
    expect(await rl.getRate()).to.equal("100");

    await expect(rl.consume("1")).to.be.reverted; // round to 1

    await rl.setTimestamp(4 * 3600); // will expire 20
    await rl.consume("1"); // round to 1
    expect(await rl.getRate()).to.equal("81");
  });

  it("expire one", async function () {
    const RateLimiterFactory = await ethers.getContractFactory("RateLimiterTest");
    const rl = await RateLimiterFactory.deploy(4, 3600, 100); // 4 hours with 1 hour per bin
    await rl.deployed();

    await rl.consume("60000000000000000000"); // 60
    expect(await rl.getRate()).to.equal("60");

    await rl.setTimestamp(4 * 3600); // will expire 60
    await rl.consume("70000000000000000000"); // round to 70
    expect(await rl.getRate()).to.equal("70");
  });

  it("expire multiple", async function () {
    const RateLimiterFactory = await ethers.getContractFactory("RateLimiterTest");
    const rl = await RateLimiterFactory.deploy(4, 3600, 100); // 4 hours with 1 hour per bin
    await rl.deployed();

    await rl.consume("60000000000000000000"); // 60
    expect(await rl.getRate()).to.equal("60");

    await rl.setTimestamp(1 * 3600); // will expire 60
    await rl.consume("30000000000000000000"); // 30
    expect(await rl.getRate()).to.equal("90");

    await rl.setTimestamp(2 * 3600); // will expire 60
    await rl.consume("10000000000000000000"); // 10
    expect(await rl.getRate()).to.equal("100");

    await rl.setTimestamp(4 * 3600); // will expire 60
    await expect(rl.consume("70000000000000000000")).to.be.reverted; // round to 70

    await rl.setTimestamp(5 * 3600); // will expire 30
    await rl.consume("70000000000000000000"); // round to 70
    expect(await rl.getRate()).to.equal("80");
  });

  it("expire all", async function () {
    const RateLimiterFactory = await ethers.getContractFactory("RateLimiterTest");
    const rl = await RateLimiterFactory.deploy(4, 3600, 100); // 4 hours with 1 hour per bin
    await rl.deployed();

    await rl.consume("10000000000000000000"); // 10
    expect(await rl.getRate()).to.equal("10");

    await rl.setTimestamp(3600 * 4);
    await rl.consume("20000000000000000000"); // 20
    expect(await rl.getRate()).to.equal("20");

    await rl.setTimestamp(3600 * 5);
    await rl.consume("30000000000000000000"); // 30
    expect(await rl.getRate()).to.equal("50");

    await rl.setTimestamp(3600 * 12);
    await rl.consume("30000000000000000000"); // 30
    expect(await rl.getRate()).to.equal("30");
  });
});
