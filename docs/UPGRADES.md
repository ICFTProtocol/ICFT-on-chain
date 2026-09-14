# Upgrade Runbook

## Purpose

This document explains how to upgrade one ICFT proxy at a time with the Foundry script:

- `script/UpgradeICFTModule.s.sol`

This flow is for the current upgradeable testnet stage.
It is not a production governance process.

## Supported Modules

Set `MODULE` to one of:

- `ICFT`
- `PriceOracle`
- `InterestRateModel`
- `RiskEngine`
- `LendingPool`
- `LiquidationEngine`

`ICFTLiquidityVault` is deployed separately by `script/DeployICFTLiquidityVault.s.sol` because it is a new proxy,
not an upgrade of an existing deployment.

## Required Environment Variables

- `RPC_URL`
- `DEPLOYER_PRIVATE_KEY`
- `PROXY_ADMIN_ADDRESS`
- `PROXY_ADDRESS`
- `MODULE`

Optional:

- `UPGRADE_CALLDATA`

Use `UPGRADE_CALLDATA` only when the new implementation adds a post-upgrade initializer or migration function.
If not needed, leave it empty. The script executes this calldata from the broadcaster after the proxy
implementation is upgraded; it must not be executed by `ProxyAdmin`, because `ProxyAdmin` does not hold
the protocol's operational roles.

## Dry Run

```bash
source .env
forge script script/UpgradeICFTModule.s.sol:UpgradeICFTModule \
  --rpc-url "$RPC_URL" \
  -vvvv
```

## Broadcast

```bash
source .env
forge script script/UpgradeICFTModule.s.sol:UpgradeICFTModule \
  --rpc-url "$RPC_URL" \
  --broadcast \
  -vvvv
```

## Example

Upgrade the lending pool proxy:

```bash
source .env
export MODULE=LendingPool
export PROXY_ADMIN_ADDRESS=<proxy-admin-address>
export PROXY_ADDRESS=<lending-pool-proxy-address>

forge script script/UpgradeICFTModule.s.sol:UpgradeICFTModule \
  --rpc-url "$RPC_URL" \
  --broadcast \
  -vvvv
```

## Post-Upgrade Checks

After each upgrade:

1. confirm the proxy still returns expected state
2. rerun a few critical reads like collateral balances, debt, and borrow index
3. confirm role-gated actions still work
4. confirm the upgraded implementation address in the explorer
5. if migration calldata was used, verify the migrated fields directly

## Safety Notes

- upgrade only one proxy per transaction flow
- never combine an upgrade with unrelated admin changes
- keep `ProxyAdmin` ownership off a casual hot wallet when moving beyond basic testnet rehearsal
- if storage layout changes, review it before broadcasting
- if a deployer or admin private key was ever exposed in chat, logs, or screenshots, rotate it before the next upgrade

## Current Module Notes

As of September 1, 2026:

- `PriceOracle` upgrades are especially sensitive because collateral-feed storage must remain append-only for proxy safety;
- `LendingPool` upgrades are especially sensitive because collateral registry storage and debt accounting storage must not be reordered;
- if enabling new collateral after deployment, the upgrade itself is not enough: the team must still execute the required admin calls in `PriceOracle` and `LendingPool`.

For the current Sepolia engineering baseline:

- `wBTC` enablement depends on a valid token address and trusted price feed for that network;
- `wstETH` enablement currently depends on a documented testnet-only oracle path;
- post-upgrade verification should always include `getSupportedCollateralAssets()` and oracle support checks for every enabled collateral asset.

## Audit Accounting Upgrade

The LendingPool audit-remediation release adds position-level issued-principal tracking, bad-debt accounting,
an insurance reserve, minimum borrow enforcement, and LP-vault integration.

It must be upgraded only while `totalScaledDebtUSD` and `totalBorrowedICFT` are both zero. This is intentional:
legacy borrower positions cannot be enumerated or safely migrated on-chain. After upgrading LendingPool,
set `UPGRADE_CALLDATA` to `0xde954445` (`initializeAuditAccountingV3()`); it rejects a migration with live
legacy debt. The upgrade script pauses LendingPool, upgrades it without proxy-admin calldata, invokes this
migration from the broadcaster, then unpauses it. The broadcaster must therefore hold both `PAUSER_ROLE`
and `CONFIG_ADMIN_ROLE` on LendingPool.

Only after that initialization succeeds may the team deploy the LP vault:

```bash
source .env
forge script script/DeployICFTLiquidityVault.s.sol:DeployICFTLiquidityVault \
  --rpc-url "$RPC_URL" \
  --broadcast \
  -vvvv
```

Before broadcasting, ensure:

1. `LENDING_POOL_PROXY` is the upgraded pool proxy.
2. The pool already holds the intended Fund A ICFT balance.
3. `LP_INITIAL_OWNER` is the entity that economically owns that Fund A balance.
4. The broadcaster currently has `DEFAULT_ADMIN_ROLE` on LendingPool, because the script grants `LP_VAULT_ROLE`.
5. `LP_VAULT_UPGRADE_ADMIN_ADDRESS` is not a casual hot wallet.
