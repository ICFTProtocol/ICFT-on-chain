# Protocol Credit Reserve Migration Plan

## Decision

ICFT's intended product model uses protocol-owned ICFT credit inventory rather than a public credit-liquidity provider model. The initial inventory is funded from the Fund A allocation. External market makers or DEX liquidity providers are a separate market-infrastructure concern and do not fund the LendingPool.

## Current Sepolia State

The deployed `LendingPool` tracks `fundALiquidityICFT`, while the separately deployed `ICFTLiquidityVault` exposes public `supply` and `redeem` methods and mints `icftLP` shares. This reflects an older testnet design and is incompatible with presenting the public protocol as a non-LP credit reserve.

The frontend has deprecated public vault interactions. The contracts must not be altered solely to match the new copy: legacy share balances, available redemption rights, and pool accounting must be understood first.

## Preconditions

Before any on-chain change, record and independently verify:

1. Vault `totalSupply`, `totalAssets`, `bootstrapped`, all material holder balances, and vault administration roles.
2. LendingPool `fundALiquidityICFT`, `totalBorrowedICFT`, `totalScaledDebtUSD`, `protocolRevenueICFT`, `insuranceReserveBps`, and `LP_VAULT_ROLE` members.
3. The vault's ability to redeem its outstanding shares under current borrow utilization.
4. Whether any non-Fund-A address owns `icftLP`; this determines whether a holder migration or redemption period is required.
5. Proxy implementation addresses, storage-layout diff, role holders, and a forked Sepolia rehearsal.

## Safe Migration Options

### Option A: Testnet reset

Use only if every holder explicitly agrees that their test assets and shares can be discarded. Deploy a clean reserve-only stack with no vault proxy. This is simplest but must never be used if it would invalidate third-party balances without consent.

### Option B: Legacy wind-down

Upgrade the vault only after storage review to block new public supply while preserving redeem for legacy holders. Keep the `LP_VAULT_ROLE` during the redemption period. After all shares are redeemed or migrated under a published process, revoke the role and retire the vault from the intended architecture.

### Option C: Governed migration

Create an audited migration contract with a time-bounded opt-in claim for holders. This is the most complex option and requires a security review, clear economics, and a pause/rollback plan.

## Intended Reserve-Only Design

1. The LendingPool uses `fundALiquidityICFT` as the protocol credit reserve.
2. Only a tightly scoped governance/reserve-manager role may fund or withdraw reserve inventory.
3. Every reserve action emits an event with the actor, amount, and reason/reference.
4. Borrower principal returns to reserve inventory on repayment.
5. Interest allocation must be approved before coding: insurance, treasury, and any future buyback reserve need explicit basis-point configuration and events.
6. No public `supply`, `redeem`, receipt token, or yield marketing exists in the production architecture.

## Market Infrastructure Is Separate

An official ICFT DEX/CEX venue can provide market depth for voluntary buying and selling, including repayment acquisition. It must not be described as the LendingPool credit reserve. Publish market cap, trading links, TVL, depth, and price only after official pairs and a credible price methodology exist.

## Upgrade Gate

Do not broadcast an upgrade until all preconditions pass, all existing share holders have a documented outcome, the storage layout has been checked, Foundry tests and a fork rehearsal pass, and the team signs an execution checklist. Sepolia is a rehearsal environment, not an exception to these controls.
