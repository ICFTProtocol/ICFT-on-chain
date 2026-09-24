# Protocol Credit Reserve Migration Plan

## Decision

ICFT's intended product model uses protocol-owned ICFT credit inventory rather than a public ICFT credit-liquidity provider model. The initial inventory is funded from the Fund A allocation. Under the canonical investor whitepaper, external market LPs contribute USDT to ICFT/USDT trading liquidity while the protocol contributes ICFT. Those LPs support market trading and do not fund the LendingPool credit reserve.

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

## USD Capacity and ICFT Price

The number of ICFT in the protocol reserve remains fixed unless an authorized reserve action changes it. If a credible ICFT/USD market price rises, the **USD value** of the same reserve rises. A new $100 loan would then transfer fewer ICFT: at $1 per ICFT it transfers 100 ICFT; at $2 it transfers 50 ICFT. This is a unit-of-account effect, not the creation of additional ICFT.

Adding USDT to a DEX pool is not by itself a reliable or sustainable mechanism for raising price. A two-sided AMM pool needs both assets, and a price that differs from the broader market will be arbitraged. Price policy, market-making, circulating supply, market depth, slippage, and manipulation resistance require an economics and risk review.

## USD-Denominated Debt and Settlement

The canonical whitepaper policy is **USD-denominated debt with settlement in ICFT at the current approved ICFT/USD price**. The LendingPool records debt in USD and uses `PriceOracle.convertUSDToICFT` when calculating full repayment. Therefore an ICFT price change changes the number of ICFT needed to settle an already-open USD debt. Example: a borrower who receives 100 ICFT for $100 at $1 would need approximately 50 ICFT principal to settle that $100 debt if the oracle later reports $2.

The whitepaper also specifies direct USDT repayment: the protocol accepts USDT, settles the USD debt, and uses USDT to acquire ICFT at the market price for circulation and/or burn under protocol rules. The codebase now contains the first, deliberately constrained stage of this path:

1. `LendingPool.repayWithUSDT` reduces the fixed USD debt at a 1 USDT = 1 USD settlement value and transfers the exact USDT amount to `USDTSettlementReserve`.
2. Full settlement is rounded up in the token's native decimals so a user cannot leave dust debt through decimal truncation.
3. `USDTSettlementReserve` accounts for pending USDT and can release it only through `MARKET_EXECUTOR_ROLE`.
4. The reserve has no DEX router integration. It does not select pools, routes, quotes, deadlines, or slippage bounds.
5. ICFT credit inventory remains reduced after a USDT repayment. It is replenished only when canonical ICFT bought externally is returned from the authorized reserve to `LendingPool`.

This is not a production market-execution system. Before enabling it on a public testnet, the team must approve the concrete venue, executor architecture, slippage and quote validation, transaction deadline, maximum trade size, failure handling, key custody, monitoring, and emergency pause procedure.

This approved behavior still requires protection before a market-derived ICFT price is adopted. A manipulated or volatile ICFT oracle can affect repayment token amounts, reserve-token accounting, borrower incentives, and liquidation economics. A production release needs at minimum a robust oracle methodology, price-deviation controls, a TWAP or equivalent where appropriate, and tests covering price movements before and after origination.

## Upgrade Gate

Do not broadcast an upgrade until all preconditions pass, all existing share holders have a documented outcome, the storage layout has been checked, Foundry tests and a fork rehearsal pass, and the team signs an execution checklist. Sepolia is a rehearsal environment, not an exception to these controls.
