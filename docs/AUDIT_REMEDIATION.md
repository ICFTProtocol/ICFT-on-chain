# Audit Remediation Status

## Scope

This document tracks remediation of `ICFT-security-review-EN.pdf`, dated September 12, 2026, against commit `7135745`.
It describes source-code changes only. Nothing here authorizes a mainnet deployment or replaces a fix review by the auditor.

## Implemented In This Working Tree

| Finding | Status | Remediation |
|---|---|---|
| H-02 | Implemented, requires testnet migration | Collateral-exhausted positions are closed, residual debt is recorded in `totalBadDebtUSD`, insurance reserve ICFT is consumed first, then LP assets absorb any remaining loss. |
| H-03 | Implemented | Risk configuration enforces a positive liquidation denominator, a 3% target/threshold gap, and a 15% maximum liquidation bonus. |
| M-01 | Implemented for new positions | Position-level `issuedPrincipalICFT` makes utilisation decrease by the original issued-principal share, not the current-price repayment token amount. |
| M-02 | Implemented | Interest is settled immediately before pause and accrual is frozen in both state-changing and preview paths until unpause. |
| M-03 | Implemented | 85% of interest becomes lendable LP value; 15% is reserved as insurance by default. `ICFTLiquidityVault` issues transferable `icftLP` shares. |
| M-04 | Implemented | New borrows require at least `100 USD` by default; the value is configurable. |
| L-01 | Implemented | Oracle reads reject zero/stale answers and incomplete Chainlink rounds. |
| L-02 | Implemented | Target LTV must remain at least 300 bps below the liquidation threshold. |
| L-03 | Implemented | Solidity pragmas and Foundry configuration pin `0.8.30`. |
| L-04 | Partially implemented | Registry growth is capped at 16 collateral assets. Per-position collateral lists remain a later gas optimization. |
| L-05 | Implemented for future upgrades | Storage gaps are reserved in all upgradeable protocol contracts. |
| L-06 | Implemented | ERC20 collateral is credited by the actual balance received. |
| L-07 | Partially implemented | APR is capped at 100%; the stepped curve remains intentionally unchanged. |

## Still Open Before Mainnet

### H-01: ICFT Oracle Governance

Manual ICFT pricing remains a testnet-only trust assumption. Mainnet requires an independent market source or source quorum,
deviation limits, a circuit breaker, and execution through a multisig-controlled timelock.

### H-04 And M-05: Privileged-Operation Governance

The existing Sepolia proxy admins and protocol roles remain single-key controlled. Before mainnet:

- transfer each ProxyAdmin to a multisig-controlled `TimelockController`;
- give daily oracle, risk, and rate configuration roles to dedicated role holders, not the upgrade owner;
- use two-step delayed role administration;
- define a maximum pause duration and incident runbook.

### Operational Limits

The V3 LendingPool accounting migration intentionally rejects live legacy debt. For a public deployment with active users,
use a migration plan with an indexed off-chain position snapshot, user notification, a controlled close-out window,
and independent review. Do not bypass this restriction.

`wstETH` pricing on the current Sepolia setup remains test-only until a production-grade feed strategy is selected.
