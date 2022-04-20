// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RateLimiterSet {
    uint256 public immutable RATE_BIN_DURATION;
    uint256 public immutable RATE_BINS;
    uint256 public immutable RATE_BIN_BYTES;
    uint256 public immutable RATE_BIN_MAX_VALUE;
    uint256 public immutable RATE_BIN_MASK;
    uint256 public immutable RATE_BINS_PER_SLOT;

    struct Rate{
        uint256  lastBinIdx;
        uint256  limit;
        uint256  rate;
        mapping(uint256 => uint256) rateSlots;
    }
    mapping(uint256 => mapping(address => Rate))
        public tokenToRateSlots;

    struct SlotCache {
        uint256 slotIdx;
        uint256 slotValue;
    }

    constructor(
        uint256 bins,
        uint256 binDuration,
        uint256 binBytes
    ) {
        RATE_BINS = bins; // Bin数量
        RATE_BIN_DURATION = binDuration; // 每个Bin的周期
        RATE_BIN_BYTES = binBytes;
        RATE_BIN_MAX_VALUE = (1 << (RATE_BIN_BYTES * 8)) - 1;
        RATE_BIN_MASK = RATE_BIN_MAX_VALUE;
        RATE_BINS_PER_SLOT = 32 / RATE_BIN_BYTES;// 每个字可以放几个Bin
    }

    // Get a new cache from a binIdx
    function _getCache(uint256 binIdx,uint256 chainId,address srcToken) internal view returns (SlotCache memory) {
        uint256 slotIdx = (binIdx % RATE_BINS) / RATE_BINS_PER_SLOT;

        return SlotCache({slotIdx: slotIdx, slotValue: tokenToRateSlots[chainId][srcToken].rateSlots[slotIdx]});
    }

    // Commit the cache to storage.
    function _commitCache(SlotCache memory cache,uint256 chainId,address srcToken) internal {
        tokenToRateSlots[chainId][srcToken].rateSlots[cache.slotIdx] = cache.slotValue;
    }

    // Flush the cache if the cache is evicted.
    function _flushIfEvicted(SlotCache memory cache, uint256 newSlotIdx,uint256 chainId,address srcToken) internal {
        if (newSlotIdx != cache.slotIdx) {
            // commit to storage
            _commitCache(cache, chainId, srcToken);

            // load from storage
            cache.slotIdx = newSlotIdx;
            cache.slotValue = tokenToRateSlots[chainId][srcToken].rateSlots[newSlotIdx];
        }
    }

    function _prepareBin(SlotCache memory cache, uint256 binIdx,uint256 chainId,address srcToken) internal returns (uint256 oldValue, uint256 off) {
        // 
        uint256 binIdxInWindow = binIdx % RATE_BINS;
        // 在哪一个slot
        uint256 slotIdx = binIdxInWindow / RATE_BINS_PER_SLOT;
        // 判断是否需要更新cache
        _flushIfEvicted(cache, slotIdx, chainId, srcToken);
        // 在slot中的具体位置
        uint256 idxInSlot = binIdxInWindow % RATE_BINS_PER_SLOT;
        off = idxInSlot * RATE_BIN_BYTES * 8;
        // 偏移之后，在slot中拿到真正的值
        oldValue = (cache.slotValue >> off) & RATE_BIN_MASK;
    }

    // Get a bin value and use cache if hit.  If not hit, evict the cache, and read a new one from storage.
    // The cache must contain valid values.
    function _getBinValue(SlotCache memory cache, uint256 binIdx,uint256 chainId,address srcToken) internal returns (uint256) {
        (uint256 oldValue, ) = _prepareBin(cache, binIdx, chainId, srcToken);
        return oldValue;
    }

    // Set a bin value and write only to cache if hit.  If not hit, evict the cache, and write to a new cache loaded from storage.
    // The cache must contain valid values.
    function _setBinValue(
        SlotCache memory cache,
        uint256 binIdx,
        uint256 value,
        uint256 chainId,
        address srcToken
    ) internal returns (uint256) {
        require(value <= RATE_BIN_MAX_VALUE, "value too big");

        (uint256 oldValue, uint256 off) = _prepareBin(cache, binIdx, chainId, srcToken);
        cache.slotValue = (cache.slotValue & (~(RATE_BIN_MASK << off))) | (value << off);
        return oldValue;
    }

    // Add a bin value and write only to cache if hit.  If not hit, evict the cache, and write to a new cache loaded from storage.
    // The cache must contain valid values.
    function _addBinValue(
        SlotCache memory cache,
        uint256 binIdx,
        uint256 value,
        uint256 chainId,
        address srcToken
    ) internal returns (uint256) {
        (uint256 oldValue, uint256 off) = _prepareBin(cache, binIdx, chainId, srcToken);
        uint256 newValue = oldValue + value;
        require(newValue <= RATE_BIN_MAX_VALUE, "value too big");
        cache.slotValue = (cache.slotValue & (~(RATE_BIN_MASK << off))) | (newValue << off);
        return oldValue;
    }

    // Overridable for testing.
    function _getTimestamp() internal virtual returns (uint256) {
        return block.timestamp;
    }

    function _setRateLimit(uint256 limit,uint256 chainId,address srcToken) internal {
        tokenToRateSlots[chainId][srcToken].limit = limit;
    }

    function getRateLimit(uint256 chainId,address srcToken) public view returns(uint256){
        return tokenToRateSlots[chainId][srcToken].limit ;
    }

    function _resetRate(uint256 chainId,address srcToken) internal {
        for (uint256 i = 0; i < (RATE_BINS + RATE_BINS_PER_SLOT - 1) / RATE_BINS_PER_SLOT; i++) {
            tokenToRateSlots[chainId][srcToken].rateSlots[i] = 0;
        }
        tokenToRateSlots[chainId][srcToken].rate = 0;
    }

    // Check if consuming amount will exceed rate limit.  Update rate accordingly.
    function _checkRateLimit(uint256 amount,uint256 chainId,address srcToken) internal {
        uint256 binIdx = _getTimestamp() / RATE_BIN_DURATION;

        // reset rate if all existing rate bins are expired
        tokenToRateSlots[chainId][srcToken].lastBinIdx;
        if (binIdx - tokenToRateSlots[chainId][srcToken].lastBinIdx >= RATE_BINS) {
            _resetRate(chainId,srcToken);
            tokenToRateSlots[chainId][srcToken].lastBinIdx = binIdx;
        }

        SlotCache memory cache = _getCache(tokenToRateSlots[chainId][srcToken].lastBinIdx, chainId, srcToken);
        uint rate = tokenToRateSlots[chainId][srcToken].rate;

        if (binIdx != tokenToRateSlots[chainId][srcToken].lastBinIdx) {
            for (uint256 idx = tokenToRateSlots[chainId][srcToken].lastBinIdx + 1; idx <= binIdx; idx++) {
                uint256 oldValue = _setBinValue(cache, idx, 0, chainId, srcToken);
                rate -= oldValue;
            }
            tokenToRateSlots[chainId][srcToken].lastBinIdx = binIdx;
        }

        rate += amount;
        require(rate <= tokenToRateSlots[chainId][srcToken].limit, "limit exceeded");
        tokenToRateSlots[chainId][srcToken].rate = rate;
        _addBinValue(cache, binIdx, amount, chainId, srcToken);
        _commitCache(cache, chainId, srcToken);
    }
}
