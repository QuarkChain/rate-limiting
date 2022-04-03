# On-Chain Rate-Limiting Contract

This repo provides an on-chain rate-limiting contract.  If the frequency of some operations exceeds the pre-defined limit, the subsequent operations will be halted until
- the owner of the contract manually resets the rate; or
- the users have to wait until the rate is lower enough.

An example of the application is in bridge, where a rate limiter is employed to limit the withdrawal/unlock amount to a specific value (e.g., $20M per day).  If the amount withdrawal in recent 24 hours exceeds the limit, the withdrawal will be suspended.  This will leave a time room for the operator to check the healthy status of the bridge and reset the rate if everything is fine.  With the rate limit, we could significantly reduce the loss of the one-time-withdraw-all  bridge attacks that are found in Wormhole/Ronin bridges.

# Comparison With Existing Implementation
Consensys has implemented a simple rate-limiting contract https://consensys.github.io/smart-contract-best-practices/development-recommendations/precautions/rate-limiting/.  However, the time granularity of rate calculation is the same as rate duartion (e.g., 24 hours), this means that the actual limit may be **twice of the limit** specified by the contract.  For example, an attacker can
- withdraw the limit amount at the end of a limiting period (suppose the pre-withdrawal amount is low in the period); and
- withdraw the limit amount at the beginning of the next period.

This repo implements a fine-time-granularity rate limiter with sliding window:
- A bin is the minimum aggregate unit to sum the rate;
- Bin duration is duration of the bin (e.g., 1 hour)
- \# of bins (e.g., 24, and thus 24 hours to calculate rate)

As a result, if the same attack strategy is employed, the attacker has to wait 23 hours to withdraw the next limit amount.

# Methods Provided by the Contract
The contract provides a constructor to specify
- \# of bins;
- bin duration;
- \# of bytes in a bin (maximum value of the bin); and
- the limit.

It further provides the following internal methods:
- _checkRateLimit(amount).  Revert if the rate exceeds the limit, otherwise, update the rate accordingly.
- _resetRate().  Reset the rate to zero.
- _setRateLimit(limit).  Set the new limit.

# Gas Cost
The average gas cost is about 20000.  May be higher if the contract is not called for a while.

# Audit
The code is not audited.  USE AT YOUR OWN RISK!
