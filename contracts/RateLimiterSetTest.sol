// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./RateLimiterSet.sol";

contract RateLimiterSetTest is RateLimiterSet {
    uint256 public timestamp;
    uint256 constant RATE_UNIT = 1e18;

    constructor(uint256 bins, uint256 binDuration) RateLimiterSet(bins, binDuration, 4) {}

    function setRateLimit(
        uint256 newLimit,
        uint256 chainId,
        address srcToken
    ) public {
        _setRateLimit(newLimit, chainId, srcToken);
    }

    function resetRate(uint256 chainId, address srcToken) public {
        _resetRate(chainId, srcToken);
    }

    function _getTimestamp() internal view override returns (uint256) {
        return timestamp;
    }

    function setTimestamp(uint256 newTimestamp) public {
        timestamp = newTimestamp;
    }

    function consume(
        uint256 amount,
        uint256 chainId,
        address srcToken
    ) public {
        uint256 amountInUnit = (amount + RATE_UNIT - 1) / RATE_UNIT;
        _checkRateLimit(amountInUnit, chainId, srcToken);
    }
}
