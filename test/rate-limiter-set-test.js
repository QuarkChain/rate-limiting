const { web3 } = require("hardhat");
const { expect } = require("chai");
const { ethers } = require("hardhat");

var ToBig = (x) => ethers.BigNumber.from(x);

const chainId = 1
const srcToken = "0x024d6050275eec53b233B467AdA12d2C65B3AEce"

describe("RateLimiter Set Test", function () {
    let rl
    beforeEach(async () => {
        const RateLimiterFactory = await ethers.getContractFactory("RateLimiterSetTest");
        rl = await RateLimiterFactory.deploy(4, 3600); // 4 hours with 1 hour per bin

        await rl.deployed();

        await rl.setRateLimit(100,chainId,srcToken)
        expect(await rl.getRateLimit(chainId,srcToken)).to.eq(100)
    })

  it("simple", async function () {

    await rl.consume("10000000000000000000",chainId,srcToken); // 10
    expect(await rl.getRate(chainId,srcToken)).to.equal("10");

    await rl.consume("10000000000000000000",chainId,srcToken); // 10
    expect(await rl.getRate(chainId,srcToken)).to.equal("20");

  });

  it("complex", async function () {

    await rl.consume("10000000000000000000",chainId,srcToken); // 10
    expect(await rl.getRate(chainId,srcToken)).to.equal("10");

    await rl.consume("10000000000000000000",chainId,srcToken); // 10
    expect(await rl.getRate(chainId,srcToken)).to.equal("20");

    await expect(rl.consume("90000000000000000000",chainId,srcToken)).to.be.reverted; // 90
    expect(await rl.getRate(chainId,srcToken)).to.equal("20");

    await rl.setTimestamp(3600);
    await rl.consume("10000000000000000000",chainId,srcToken); // 10
    expect(await rl.getRate(chainId,srcToken)).to.equal("30");

    await rl.setTimestamp(2 * 3600);
    await rl.consume("20000000000000000000",chainId,srcToken); // 20
    expect(await rl.getRate(chainId,srcToken)).to.equal("50");

    await rl.setTimestamp(3 * 3600);
    await rl.consume("50000000000000000000",chainId,srcToken); // 50
    expect(await rl.getRate(chainId,srcToken)).to.equal("100");

    await expect(rl.consume("1",chainId,srcToken)).to.be.reverted; // round to 1

    await rl.setTimestamp(4 * 3600); // will expire 20
    await rl.consume("1",chainId,srcToken); // round to 1
    expect(await rl.getRate(chainId,srcToken)).to.equal("81");
  });

  it("expire one", async function () {

    await rl.consume("60000000000000000000",chainId,srcToken); // 60
    expect(await rl.getRate(chainId,srcToken)).to.equal("60");

    await rl.setTimestamp(4 * 3600); // will expire 60
    await rl.consume("70000000000000000000",chainId,srcToken); // round to 70
    expect(await rl.getRate(chainId,srcToken)).to.equal("70");
  });

  it("expire multiple", async function () {

    await rl.consume("60000000000000000000",chainId,srcToken); // 60
    expect(await rl.getRate(chainId,srcToken)).to.equal("60");

    await rl.setTimestamp(1 * 3600); // will expire 60
    await rl.consume("30000000000000000000",chainId,srcToken); // 30
    expect(await rl.getRate(chainId,srcToken)).to.equal("90");

    await rl.setTimestamp(2 * 3600); // will expire 60
    await rl.consume("10000000000000000000",chainId,srcToken); // 10
    expect(await rl.getRate(chainId,srcToken)).to.equal("100");

    await rl.setTimestamp(4 * 3600); // will expire 60
    await expect(rl.consume("70000000000000000000",chainId,srcToken)).to.be.reverted; // round to 70

    await rl.setTimestamp(5 * 3600); // will expire 30
    await rl.consume("70000000000000000000",chainId,srcToken); // round to 70
    expect(await rl.getRate(chainId,srcToken)).to.equal("80");
  });

  it("expire all", async function () {
    
    await rl.consume("10000000000000000000",chainId,srcToken); // 10
    expect(await rl.getRate(chainId,srcToken)).to.equal("10");

    await rl.setTimestamp(3600 * 4);
    await rl.consume("20000000000000000000",chainId,srcToken); // 20
    expect(await rl.getRate(chainId,srcToken)).to.equal("20");

    await rl.setTimestamp(3600 * 5);
    await rl.consume("30000000000000000000",chainId,srcToken); // 30
    expect(await rl.getRate(chainId,srcToken)).to.equal("50");

    await rl.setTimestamp(3600 * 12);
    await rl.consume("30000000000000000000",chainId,srcToken); // 30
    expect(await rl.getRate(chainId,srcToken)).to.equal("30");
  });
});
