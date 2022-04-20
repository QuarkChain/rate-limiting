// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RateLimiter {
    uint256 public immutable RATE_BIN_DURATION;
    uint256 public immutable RATE_BINS;
    uint256 public immutable RATE_BIN_BYTES;
    uint256 public immutable RATE_BIN_MAX_VALUE;
    uint256 public immutable RATE_BIN_MASK;
    uint256 public immutable RATE_BINS_PER_SLOT;

    mapping(uint256 => uint256) private _rateSlots;
    uint256 private _lastBinIdx;
    uint256 internal _limit;
    uint256 internal _rate;

    struct SlotCache {
        uint256 slotIdx;
        uint256 slotValue;
    }

    constructor(
        uint256 bins,
        uint256 binDuration,
        uint256 binBytes,
        uint256 limit
    ) {
        RATE_BINS = bins;
        RATE_BIN_DURATION = binDuration;
        RATE_BIN_BYTES = binBytes;
        RATE_BIN_MAX_VALUE = (1 << (RATE_BIN_BYTES * 8)) - 1;
        RATE_BIN_MASK = RATE_BIN_MAX_VALUE;
        RATE_BINS_PER_SLOT = 32 / RATE_BIN_BYTES;
        _limit = limit;
    }

    // Get a new cache from a binIdx
    function _getCache(uint256 binIdx) internal view returns (SlotCache memory) {
        uint256 slotIdx = (binIdx % RATE_BINS) / RATE_BINS_PER_SLOT;

        return SlotCache({slotIdx: slotIdx, slotValue: _rateSlots[slotIdx]});
    }

    // Commit the cache to storage.
    function _commitCache(SlotCache memory cache) internal {
        _rateSlots[cache.slotIdx] = cache.slotValue;
    }

    // Flush the cache if the cache is evicted.
    function _flushIfEvicted(SlotCache memory cache, uint256 newSlotIdx) internal {
        if (newSlotIdx != cache.slotIdx) {
            // commit to storage
            _commitCache(cache);

            // load from storage
            cache.slotIdx = newSlotIdx;
            cache.slotValue = _rateSlots[newSlotIdx];
        }
    }

    function _prepareBin(SlotCache memory cache, uint256 binIdx) internal returns (uint256 oldValue, uint256 off) {
        uint256 binIdxInWindow = binIdx % RATE_BINS;
        uint256 slotIdx = binIdxInWindow / RATE_BINS_PER_SLOT;
        _flushIfEvicted(cache, slotIdx);
        uint256 idxInSlot = binIdxInWindow % RATE_BINS_PER_SLOT;
        off = idxInSlot * RATE_BIN_BYTES * 8;
        oldValue = (cache.slotValue >> off) & RATE_BIN_MASK;
    }

    // Get a bin value and use cache if hit.  If not hit, evict the cache, and read a new one from storage.
    // The cache must contain valid values.
    function _getBinValue(SlotCache memory cache, uint256 binIdx) internal returns (uint256) {
        (uint256 oldValue, ) = _prepareBin(cache, binIdx);
        return oldValue;
    }

    // Set a bin value and write only to cache if hit.  If not hit, evict the cache, and write to a new cache loaded from storage.
    // The cache must contain valid values.
    function _setBinValue(
        SlotCache memory cache,
        uint256 binIdx,
        uint256 value
    ) internal returns (uint256) {
        require(value <= RATE_BIN_MAX_VALUE, "value too big");

        (uint256 oldValue, uint256 off) = _prepareBin(cache, binIdx);
        cache.slotValue = (cache.slotValue & (~(RATE_BIN_MASK << off))) | (value << off);
        return oldValue;
    }

    // Add a bin value and write only to cache if hit.  If not hit, evict the cache, and write to a new cache loaded from storage.
    // The cache must contain valid values.
    function _addBinValue(
        SlotCache memory cache,
        uint256 binIdx,
        uint256 value
    ) internal returns (uint256) {
        (uint256 oldValue, uint256 off) = _prepareBin(cache, binIdx);
        uint256 newValue = oldValue + value;
        require(newValue <= RATE_BIN_MAX_VALUE, "value too big");
        cache.slotValue = (cache.slotValue & (~(RATE_BIN_MASK << off))) | (newValue << off);
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

        // reset rate if all existing rate bins are expired
        if (binIdx - _lastBinIdx >= RATE_BINS) {
            _resetRate();
            _lastBinIdx = binIdx;
        }

        SlotCache memory cache = _getCache(_lastBinIdx);
        uint256 rate = _rate;

        if (binIdx != _lastBinIdx) {
            for (uint256 idx = _lastBinIdx + 1; idx <= binIdx; idx++) {
                uint256 oldValue = _setBinValue(cache, idx, 0);
                rate -= oldValue;
            }
            _lastBinIdx = binIdx;
        }

        rate += amount;
        require(rate <= _limit, "limit exceeded");
        _rate = rate;
        _addBinValue(cache, binIdx, amount);
        _commitCache(cache);
    }
}
