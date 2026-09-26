# Sepolia wstETH Oracle Incident

## Status

Contained on 2026-09-25. LendingPool remains paused. This is a Sepolia testnet incident; no mainnet deployment is authorized from this state.

## Impact

The configured wstETH/USD feed returned an implausible positive value with valid feed decimals and a fresh timestamp. The prior oracle implementation accepted any positive, fresh answer. A borrower used a small wstETH deposit to pass the LTV check and borrow approximately 180 million test ICFT.

## Root Cause

The oracle checked answer positivity, round completeness, staleness, and feed decimals, but had no asset-specific USD price bounds. Therefore an erroneous or maliciously configured feed could inflate collateral value.

## On-Chain Containment

- LendingPool paused.
- `LP_VAULT_ROLE` revoked from the LP vault.
- wstETH disabled in LendingPool.
- wstETH disabled in PriceOracle.

The emergency transaction hashes and current state must be retained in the operational incident record before any future upgrade.

## Permanent Remediation

The next PriceOracle implementation introduces fail-closed collateral bounds:

- Every asset, including native ETH, requires an explicit min/max USD range.
- An ERC-20 feed cannot be enabled without configured bounds.
- Enabling a feed validates its current Chainlink answer against those bounds.
- Every price used by collateral conversion validates against the configured bounds.
- Regression tests reproduce the inflated-wstETH deposit and verify that borrowing reverts.

## Recovery Gate

Do not unpause until all conditions are complete:

1. Upgrade the oracle on a fork rehearsal.
2. Configure and independently verify native ETH and wBTC price bounds.
3. Keep wstETH disabled until a trusted target-network feed and bounds are reviewed.
4. Verify normal borrow, repay, withdrawal, and failed out-of-range-price paths on the fork.
5. Obtain team approval for the Sepolia upgrade transaction bundle.
6. Update the frontend to remove wstETH and display maintenance mode while the pool is paused.

## Key Handling

Private keys shown in chat, screenshots, terminals, or logs are compromised for operational purposes. Rotate all exposed testnet keys before the next deployment. Never use them for mainnet accounts.
