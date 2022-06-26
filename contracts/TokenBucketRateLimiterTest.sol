// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TokenBucketRateLimiter.sol";

contract TokenBucketRateLimiterTest is TokenBucketRateLimiter {
    uint256 public timestamp;

    constructor(uint256 refillRate, uint256 tokenCapacity) TokenBucketRateLimiter(refillRate, tokenCapacity, true) {}

    function setTimestamp(uint256 newTimestamp) public {
        timestamp = newTimestamp;
    }

    function consume(uint256 amount) public {
        _consume(timestamp, amount);
    }

    function getRate() public view returns (uint256) {
        return TOKEN_CAPACITY - availableTokens(timestamp);
    }
}
