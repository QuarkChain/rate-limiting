// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./RateLimiter.sol";

contract RateLimiterTest is RateLimiter {
    uint256 public timestamp;

    constructor(
        uint256 bins,
        uint256 binDuration,
        uint256 limit
    ) RateLimiter(bins, binDuration, limit) {}

    function setRateLimit(uint256 newLimit) public {
        _setRateLimit(newLimit);
    }

    function resetRate() public {
        _resetRate();
    }

    function _getTimestamp() internal view override returns (uint256) {
        return timestamp;
    }

    function setTimestamp(uint256 newTimestamp) public {
        timestamp = newTimestamp;
    }

    function consume(uint256 amount) public {
        _checkRateLimit(amount);
    }

    function getRate() public view returns (uint256) {
        return _rate;
    }
}
