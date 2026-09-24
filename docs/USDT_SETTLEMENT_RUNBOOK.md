# USDT Settlement Runbook

## Purpose

This runbook prepares the whitepaper-defined USDT repayment rail for a controlled testnet rehearsal. It does not authorize production deployment and it does not provide an automated DEX buyback bot.

The accounting flow is deliberately split:

1. A borrower calls `LendingPool.repayWithUSDT`.
2. The pool lowers the fixed USD debt and transfers the exact USDT amount to `USDTSettlementReserve`.
3. The reserve records that USDT as `pendingSettlementUSDT`.
4. A separately approved executor performs a reviewed market purchase outside this initial module.
5. The executor sends canonical ICFT to the reserve.
6. The reserve calls `LendingPool.replenishCreditReserveFromMarket`, returning bought ICFT to Fund A credit inventory.

At step 2, debt is settled but Fund A ICFT inventory remains reduced. This conservative design prevents the protocol from lending the same ICFT twice before a market purchase succeeds.

## Required Environment Variables

Add these values to the operator's untracked `.env`. Never commit private keys.

```dotenv
# Existing values
DEPLOYER_PRIVATE_KEY=0x...
RPC_URL=https://...
LENDING_POOL_PROXY=0x...

# New reserve deployment values
USDT_SETTLEMENT_ASSET=0x...                 # Canonical USDT ERC20 for the selected network
USDT_SETTLEMENT_ADMIN=0x...                 # Multisig or testnet admin, never a personal production wallet
USDT_SETTLEMENT_UPGRADE_ADMIN=0x...         # ProxyAdmin owner / governance address
USDT_MARKET_EXECUTOR=0x...                  # Dedicated executor, ideally a multisig-controlled automation address
```

`USDT_SETTLEMENT_ASSET` must be an ERC20 with no more than 18 decimals. The current implementation assigns it a fixed 1 USDT = 1 USD settlement value. Do not use a depegged or fee-on-transfer asset.

## Rehearsal Sequence

1. Run `forge test` and conduct a fork rehearsal against the target network.
2. Review the LendingPool storage-layout diff before upgrading the existing proxy.
3. Dry-run reserve deployment:

```bash
source .env
forge script script/DeployUSDTSettlementReserve.s.sol:DeployUSDTSettlementReserve \
  --rpc-url "$RPC_URL" -vvvv
```

4. Broadcast the reserve deployment only after peer review. Record its proxy and ProxyAdmin addresses.
5. Encode the LendingPool V4 initializer using the deployed reserve address:

```bash
cast calldata "initializeUSDTSettlementV4(address,address)" \
  "$USDT_SETTLEMENT_ASSET" "$USDT_SETTLEMENT_RESERVE_PROXY"
```

6. Set `MODULE=LendingPool`, the known LendingPool `PROXY_ADDRESS` and `PROXY_ADMIN_ADDRESS`, then use the encoded data as `UPGRADE_CALLDATA` with `UpgradeICFTModule.s.sol`.
7. Verify, at minimum, `usdtSettlementAsset`, `usdtSettlementReserve`, `usdtSettlementAssetDecimals`, reserve `settlementAsset`, reserve `lendingPool`, and the reserve role on LendingPool.
8. Perform one small borrower repayment with an allowlisted test USDT and verify that USDT is pending in the reserve while Fund A inventory has not increased.
9. Rehearse the executor route and the return of bought ICFT only with explicit quote, slippage, deadline, and custody controls.

## Explicit Non-Goals

- This module does not select or call Uniswap, a CEX, an aggregator, or any other venue.
- It has no hardcoded route, price quote, deadline, slippage limit, trade-size cap, or automated burn.
- `MARKET_EXECUTOR_ROLE` is operationally sensitive. For production it must be governed by a reviewed execution contract and multisig/timelock controls, not an unattended hot wallet.
- No public Sepolia upgrade should be broadcast based only on this document.
