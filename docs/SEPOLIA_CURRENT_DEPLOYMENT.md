# Current Sepolia Deployment

## Scope

This is the clean Sepolia borrower-demo deployment created after the retired wstETH oracle incident. It is a testnet release, not a production deployment.

## Contracts

| Component | Address |
| --- | --- |
| ICFT | `0xd3607F62dE598546e11f2C7bA8f3fDE042F652fa` |
| PriceOracle | `0x59DD43D580A4aeBE84FdE44E748DB7F9CdA905a4` |
| InterestRateModel | `0xFe6DcaE198d0E66eC32A6d8Cac36a4f232d35feC` |
| RiskEngine | `0x5165b90893fAa2647cA29DbE46c4969780cA0bcC` |
| LendingPool | `0xAA34c13F7932eBb77dA286F35Dc95aA13CD7626A` |
| LiquidationEngine | `0x85f6B6a0a384f5DB28E972b91D97Cd7aC1e0980e` |

## Verified Configuration

- Deployment block: `11799163`.
- Fund A: `200,000,000 ICFT` in the new LendingPool.
- Active collateral: native ETH and wBTC (`0x29f2D40B0605204364af54EC677bD022dA425d03`).
- wstETH: disabled and absent from the LendingPool supported-assets list.
- ETH oracle bounds: `$500` through `$10,000`.
- wBTC oracle bounds: `$10,000` through `$250,000`.
- ICFT/USD: manual `$1` bootstrap price. This is not an ICFT/USDT market TWAP.
- Keeper: monitoring-only by default. `EXECUTION_ENABLED=false` means it cannot submit transactions.

## Demo Limits

The release supports the ETH borrower flow: deposit, borrow ICFT, repay ICFT, and withdraw collateral. It does not include a public ICFT LP vault, a live ICFT/USDT venue, USDT repayment, DEX buybacks, automatic collateral sales, a market TWAP, or self-liquidation. Do not represent those planned components as live functionality.

The prior Sepolia deployment remains paused and retired. Never point the frontend, keeper, or testers to its addresses.
