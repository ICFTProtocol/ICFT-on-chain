# Whitepaper Alignment Baseline

## Canonical Source

For current product and implementation work, the canonical business specification is:

- `ICFT_PROTOCOL_DOCS/ICFT_White_Paper_v10_RU_Investor.html`

This document matches the deployed allocation structure: Fund A 200 million ICFT, Liquidity / LP 150 million ICFT, strategic reserve 280 million ICFT, future investors 160 million ICFT, founder 80 million ICFT, developers 100 million ICFT, and ecosystem 30 million ICFT.

Older whitepaper and tokenomics files remain historical context. Where they differ from the canonical investor whitepaper, they must not silently override it.

## Confirmed Economic Rules

1. Fund A is protocol-owned ICFT credit inventory.
2. External LPs provide USDT to ICFT/USDT market pools; the protocol provides ICFT liquidity. External LPs do not provide ICFT to the LendingPool credit reserve.
3. Debt principal is fixed in USD at origination.
4. ICFT required for repayment equals current USD obligation divided by current approved ICFT/USD price.
5. A higher ICFT price means fewer ICFT are issued for the same USD loan and fewer ICFT are needed to settle the same USD debt.
6. A lower ICFT price means more ICFT are required to settle the same USD debt; the whitepaper specifies a direct USDT repayment alternative.
7. Ten percent of protocol income is intended for buyback and burn, subject to the future implemented policy and available real revenue.

## Current Implementation Status

### Implemented in the Sepolia MVP

- Fixed 1 billion ICFT supply and deployed allocation structure.
- Fund A ICFT inventory and utilization-based borrowing limits.
- USD-denominated debt accounting.
- ICFT repayment using the current configured ICFT/USD price.
- Optional USDT repayment through an upgradeable settlement reserve. USDT is held pending market execution;
  it does not immediately recreate ICFT credit inventory.
- A role-gated path to return market-bought canonical ICFT to Fund A credit inventory after settlement.
- ETH, wBTC, and wstETH collateral for the current testnet baseline.
- Interest accrual, risk limits, liquidations, insurance accounting, upgradeable modules, frontend borrower flows, and a dry-run keeper.

### Not Implemented Yet

- An approved ICFT/USDT market purchase executor. The current reserve deliberately has no embedded DEX router,
  route, quote, deadline, slippage policy, or automated buyback execution.
- An approved ICFT/USDT market venue, protocol-provided ICFT market liquidity, and external-USDT-LP integration.
- A production-grade ICFT/USD market oracle with manipulation resistance.
- Buyback and burn execution, accounting, limits, and reporting.
- USDT insurance, stabilization, profit, and liquidity-reserve contracts.
- Market-depth, position-size, and slippage controls tied to actual ICFT trading liquidity.
- Whitepaper-defined maturity, overdue penalties, and the full USDT settlement rules.
- Governance, multisig/timelock, production risk controls, formal audit remediation, and mainnet readiness.

## Engineering Order

1. Preserve the Sepolia borrower demo and deprecate legacy public ICFT LP actions.
2. Deploy and configure the tested USDT repayment and reserve-accounting module only after a storage-layout and fork review.
3. Add an approved ICFT market-price oracle only after a real venue and liquidity methodology exist.
4. Integrate verified ICFT/USDT market routing with strict slippage and liquidity limits.
5. Add buyback/burn and USDT reserve modules after their policy parameters are represented on-chain.
6. Run fork tests, adversarial oracle tests, economic simulations, independent review, and only then consider a production deployment.
