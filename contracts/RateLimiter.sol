// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RateLimter {
    uint256 constant public RATE_UNIT = 1e18;
    uint256 constant public RATE_BIN_DURATION = 3600;
    uint256 constant public RATE_BINS = 24;
    uint256 constant public RATE_DURATION = RATE_BINS * RATE_BIN_DURATION;
    uint256 constant public RATE_BIN_BYTES = 4;
    uint256 constant public RATE_BIN_MAX_VALUE = (1 << RATE_BIN_BYTES) - 1;
    uint256 constant public RATE_BIN_MASK = (1 << RATE_BIN_BYTES) - 1;
    uint256 constant public RATE_BINS_PER_SLOT = 32 / RATE_BIN_BYTES;

    mapping (uint256 => uint256) private rateSlots;
    uint256 private lastBinIdx;
    uint256 private limit;
    uint256 private rate;

    struct BinCache {
        uint256 slotIdx;
        uint256 slotValue;
    }

    // Get a new cache from a binIdx
    function getCache(uint256 binIdx) internal view returns (BinCache memory) {
        uint256 slotIdx = binIdx / RATE_BINS_PER_SLOT;

        return BinCache({slotIdx: slotIdx, slotValue: rateSlots[slotIdx]});
    }

    // Commit the cache to storage.
    function commitCache(BinCache memory cache) internal {
        rateSlots[cache.slotIdx] = cache.slotValue;
    }

    // Flush the cache if the cache is evicted.
    function flushIfEvicted(BinCache memory cache, uint256 newSlotIdx) internal {
        if (newSlotIdx != cache.slotIdx) {
            // commit to storage
            commitCache(cache);

            // load from storage
            cache.slotIdx = newSlotIdx;
            cache.slotValue = rateSlots[newSlotIdx];
        }
    }

    // Get a bin value and use cache if hit.  If not hit, evict the cache, and read a new one from storage.
    function getBinValue(BinCache memory cache, uint256 binIdx) internal returns (uint256) {
        uint256 slotIdx = binIdx / RATE_BINS_PER_SLOT;
        flushIfEvicted(cache, slotIdx);        

        uint256 idxInSlot = binIdx % RATE_BINS_PER_SLOT;
        return cache.slotValue >> (idxInSlot * RATE_BIN_BYTES * 8) & RATE_BIN_MASK;
    }

    // Set a bin value and write only to cache if hit.  If not hit, evict the cache, and write to a new cache loaded from storage.
    function setBinValue(BinCache memory cache, uint256 binIdx, uint256 value) internal returns (uint256) {
        require(value <= RATE_BIN_MAX_VALUE, "value too big");
        uint256 slotIdx = binIdx / RATE_BINS_PER_SLOT;
        flushIfEvicted(cache, slotIdx);

        uint256 idxInSlot = binIdx % RATE_BINS_PER_SLOT;
        uint256 off = idxInSlot * RATE_BIN_BYTES * 8;
        uint256 oldValue = (cache.slotValue >> off) & RATE_BIN_MASK;
        cache.slotValue = (cache.slotValue & (~(RATE_BIN_MASK << off))) | (value << off);
        return oldValue;
    }

    // Overridable for testing.
    function getTimestamp() internal virtual returns (uint256) {
        return block.timestamp;
    }

    function setRateLimit(uint256 newLimit) internal {
        limit = newLimit;
    }

    function resetRate() internal {
        for (uint256 i = 0; i < (RATE_BINS + RATE_BINS_PER_SLOT - 1) / RATE_BINS_PER_SLOT; i++) {
            rateSlots[i] = 0;
        }
        rate = 0;
    }

    // Check if consuming amount will exceed rate limit.  Update rate accordingly.
    function checkRateLimit(uint256 amount) internal {
        uint256 binIdx = (block.timestamp % RATE_DURATION) / RATE_BIN_DURATION;
        uint256 amountInUnit = (amount + RATE_UNIT - 1) / RATE_UNIT;
        BinCache memory cache = getCache(lastBinIdx);

        if (binIdx != lastBinIdx) {
            uint256 idx = lastBinIdx;
            uint256 currentRate = rate;
            while (idx != binIdx) {
                // move to next idx
                idx = idx + 1;
                if (idx == RATE_BINS) {
                    idx = 0;
                }

                uint256 oldValue = setBinValue(cache, idx, 0);
                currentRate -= oldValue;
            }
            lastBinIdx = idx;
            rate = currentRate;
        }

        require(rate + amountInUnit <= limit, "limit exceeded");
        rate += amountInUnit;
        setBinValue(cache, binIdx, getBinValue(cache, binIdx) + amountInUnit);
        commitCache(cache);
    }
}