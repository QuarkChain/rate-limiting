// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TokenBucketRateLimiter {
    uint256 public immutable REFILL_RATE;
    uint256 public immutable TOKEN_CAPACITY;

    uint256 public lastRefill;
    uint256 public tokens;

    constructor(
        uint256 refillRate,
        uint256 tokenCapacity,
        bool fillImmediately
    ) {
        REFILL_RATE = refillRate;
        TOKEN_CAPACITY = tokenCapacity;
        if (fillImmediately) {
            tokens = TOKEN_CAPACITY;
        }
    }

    function availableTokens(uint256 ts) public view returns (uint256 newTokens) {
        uint256 toRefill = (ts - lastRefill) * REFILL_RATE;
        newTokens = tokens + toRefill;
        if (newTokens > TOKEN_CAPACITY) {
            newTokens = TOKEN_CAPACITY;
        }
    }

    // Check if consuming amount will exceed rate limit.  Update rate accordingly.
    function _consume(uint256 ts, uint256 amount) internal {
        uint256 newTokens = availableTokens(ts);
        require(amount <= newTokens, "limit exceeded");
        tokens = newTokens - amount;
        lastRefill = ts;
    }
}
