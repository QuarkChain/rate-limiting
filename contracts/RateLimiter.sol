// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RateLimiter {
    uint256 constant public RATE_UNIT = 1e18;
    uint256 immutable public RATE_BIN_DURATION;
    uint256 immutable public RATE_BINS;
    uint256 constant public RATE_BIN_BYTES = 4;
    uint256 constant public RATE_BIN_MAX_VALUE = (1 << (RATE_BIN_BYTES * 8)) - 1;
    uint256 constant public RATE_BIN_MASK = (1 << (RATE_BIN_BYTES * 8)) - 1;
    uint256 constant public RATE_BINS_PER_SLOT = 32 / RATE_BIN_BYTES;

    mapping (uint256 => uint256) private _rateSlots;
    uint256 private _lastBinIdx;
    uint256 internal _limit;
    uint256 internal _rate;

    struct BinCache {
        uint256 slotIdx;
        uint256 slotValue;
    }

    constructor (uint256 bins, uint256 binDuration, uint256 limit) {
        RATE_BINS = bins;
        RATE_BIN_DURATION = binDuration;
        _limit = limit;
    }

    // Get a new cache from a binIdx
    function _getCache(uint256 binIdx) internal view returns (BinCache memory) {
        uint256 slotIdx = (binIdx % RATE_BINS) / RATE_BINS_PER_SLOT;

        return BinCache({slotIdx: slotIdx, slotValue: _rateSlots[slotIdx]});
    }

    // Commit the cache to storage.
    function _commitCache(BinCache memory cache) internal {
        _rateSlots[cache.slotIdx] = cache.slotValue;
    }

    // Flush the cache if the cache is evicted.
    function _flushIfEvicted(BinCache memory cache, uint256 newSlotIdx) internal {
        if (newSlotIdx != cache.slotIdx) {
            // commit to storage
            _commitCache(cache);

            // load from storage
            cache.slotIdx = newSlotIdx;
            cache.slotValue = _rateSlots[newSlotIdx];
        }
    }

    // Get a bin value and use cache if hit.  If not hit, evict the cache, and read a new one from storage.
    function _getBinValue(BinCache memory cache, uint256 binIdx) internal returns (uint256) {
        uint256 binIdxInWindow = binIdx % RATE_BINS;
        uint256 slotIdx = binIdxInWindow / RATE_BINS_PER_SLOT;
        _flushIfEvicted(cache, slotIdx);        

        uint256 idxInSlot = binIdxInWindow % RATE_BINS_PER_SLOT;
        return cache.slotValue >> (idxInSlot * RATE_BIN_BYTES * 8) & RATE_BIN_MASK;
    }

    // Set a bin value and write only to cache if hit.  If not hit, evict the cache, and write to a new cache loaded from storage.
    function _setBinValue(BinCache memory cache, uint256 binIdx, uint256 value) internal returns (uint256) {
        require(value <= RATE_BIN_MAX_VALUE, "value too big");
        uint256 binIdxInWindow = binIdx % RATE_BINS;
        uint256 slotIdx = binIdxInWindow / RATE_BINS_PER_SLOT;
        _flushIfEvicted(cache, slotIdx);

        uint256 idxInSlot = binIdxInWindow % RATE_BINS_PER_SLOT;
        uint256 off = idxInSlot * RATE_BIN_BYTES * 8;
        uint256 oldValue = (cache.slotValue >> off) & RATE_BIN_MASK;
        cache.slotValue = (cache.slotValue & (~(RATE_BIN_MASK << off))) | (value << off);
        return oldValue;
    }

    // Overridable for testing.
    function _getTimestamp() internal virtual returns (uint256) {
        return block.timestamp;
    }

    function _setRateLimit(uint256 newLimit) internal {
        _limit = newLimit;
    }

    function _resetRate() internal {
        for (uint256 i = 0; i < (RATE_BINS + RATE_BINS_PER_SLOT - 1) / RATE_BINS_PER_SLOT; i++) {
            _rateSlots[i] = 0;
        }
        _rate = 0;
    }

    // Check if consuming amount will exceed rate limit.  Update rate accordingly.
    function _checkRateLimit(uint256 amount) internal {
        uint256 binIdx = _getTimestamp() / RATE_BIN_DURATION;
        uint256 amountInUnit = (amount + RATE_UNIT - 1) / RATE_UNIT;

        // reset rate if all existing rate bins are expired
        if (binIdx - _lastBinIdx >= RATE_BINS) {
            _resetRate();
            _lastBinIdx = binIdx;
        }

        BinCache memory cache = _getCache(_lastBinIdx);
        uint256 rate = _rate;

        if (binIdx != _lastBinIdx) {
            for (uint256 idx = _lastBinIdx + 1; idx <= binIdx; idx ++) {
                uint256 oldValue = _setBinValue(cache, idx, 0);
                rate -= oldValue;
            }
            _lastBinIdx = binIdx;
        }

        rate += amountInUnit;
        require(rate <= _limit, "limit exceeded");
        _rate = rate;
        _setBinValue(cache, binIdx, _getBinValue(cache, binIdx) + amountInUnit);
        _commitCache(cache);
    }
}