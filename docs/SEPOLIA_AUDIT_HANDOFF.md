# Sepolia Audit Handoff

Last verified: 2026-10-14. Network: Ethereum Sepolia (`11155111`). This is a testnet baseline, not a mainnet deployment.

## Canonical Addresses

| Component | Proxy or account | Current implementation | Notes |
| --- | --- | --- | --- |
| Safe, 2 of 3 | `0x6Df269085f5e4897738B279fB01aC67B6A9BF888` | n/a | Governance signer Safe |
| TimelockController | `0xC4684C03F118c5D39F97f1F837132cEd65d947b1` | n/a | `getMinDelay() = 86400` seconds |
| LendingPool | `0xAA34c13F7932eBb77dA286F35Dc95aA13CD7626A` | `0x08052c2b746399217aF2C9705899b7936346d221` | Public borrower-demo pool |
| LendingPool ProxyAdmin | `0x362dD0ed3C1a5D983cb57703A6e73A5616f1526f` | n/a | `owner() = TimelockController` |
| PriceOracle | `0x59DD43D580A4aeBE84FdE44E748DB7F9CdA905a4` | `0x54834e357bAb6Bf0bA940bC8598b4af9AC37BA50` | ETH, wBTC and manual ICFT price |
| RiskEngine | `0x5165b90893fAa2647cA29DbE46c4969780cA0bcC` | `0xc49bAeDDEf1e3B0f7168A075B39DABf7b5090C77` | LTV and liquidation parameters |
| InterestRateModel | `0xFe6DcaE198d0E66eC32A6d8Cac36a4f232d35feC` | `0xD5ca1058A1D24D5E163684E5181f4A247804a17E` | Borrow-rate curve |
| LiquidationEngine | `0x85f6B6a0a384f5DB28E972b91D97Cd7aC1e0980e` | `0x748c778FC684B8a8D5027f2B4a88FaC6DE304418` | Controlled liquidation entry point |
| ICFT | `0xd3607F62dE598546e11f2C7bA8f3fDE042F652fa` | `0xcD7797d27848ba928E5eC2778B6990C2Ba1752D3` | Protocol token |
| Test wBTC collateral | `0x29f2D40B0605204364af54EC677bD022dA425d03` | n/a | Enabled test collateral, 8 decimals |
| Keeper operator EOA | `0xFebAC077140DBdE927adb27A3E4FcCa846B6E7DB` | n/a | Testnet-only operator; no private key is in this repository |

## Verified Public Baseline

- LendingPool is unpaused.
- Active collateral is native ETH and test wBTC. Retired wstETH is not part of the supported-assets list.
- Risk parameters: max LTV `8000`, liquidation threshold `9000`, target LTV `8500`, liquidation bonus `500` basis points.
- The ICFT/USD value is a manual `$1` bootstrap value. It is not an ICFT/USDT market TWAP.
- The keeper is monitoring-only by default. Its execution configuration requires an explicit allowlist and is not enabled by this document.

## Threat Model and Status

| Vector | Current public-V6 design | Status |
| --- | --- | --- |
| Upgrade authority | LendingPool proxy admin is owned by TimelockController; governance actions require Safe 2 of 3 and a 24-hour delay. | Deployed |
| Privileged roles | Administrative and liquidation permissions are role-gated; no deployer key is used as the keeper operator. | Deployed; role and liquidation scenario require re-test after any upgrade |
| Oracle input | ETH and wBTC values are bounded; ICFT uses a manual testnet bootstrap price. | Deployed; not a production oracle design |
| Stale oracle withdrawal | Existing debt positions remain risk-checked against oracle data. The zero-debt withdrawal exception is in the remediation candidate. | Pending upgrade |
| LTV precision | Existing V6 has standard risk checks. Exact no-rounding-in-borrower-favor checks are in the remediation candidate. | Pending upgrade |
| LP accounting donation | Direct ICFT transfer to the pool can desynchronise displayed share assets from accounting liquidity. Candidate uses `fundALiquidityICFT + outstandingDebtICFT`, rather than raw ICFT token balance. | Pending upgrade |
| Collateral removal | Public V6 uses a collateral whitelist. Candidate adds removal only after the asset is disabled and the pool balance is zero. | Pending upgrade |
| Liquidation automation | Keeper is intentionally restricted: monitoring by default, explicit execution flags, test-address allowlist, and a separate operator wallet. | Monitoring ready; controlled execution proof pending |
| Rate changes and accrual | Rate-parameter settlement policy and accrual-frequency behaviour remain a separate audit and governance workstream. | Open scope; not claimed fixed |
| Frontend / wallet UX | Current production dApp had an unconnected-wallet read failure that disabled actions. A fix separates global reads from position reads and opens wallet selection on an action click. | Fix branch pushed; pending Vercel deployment and external UX test |

## Remediation Candidate

Branch: `fix/v6-audit-remediation-release` in `ICFTProtocol/ICFT-on-chain`.

The candidate changes LendingPool implementation only. It introduces no new storage variables and retains the existing proxy storage layout. Targeted contract and fuzz tests: `49 passed, 0 failed`. The candidate must undergo auditor review and a fork rehearsal before any implementation deployment or Safe scheduling.

## Audit Request

Please use this address registry as the single Sepolia reference. We request review of the remediation candidate, then one controlled unsafe-position liquidation proof using only an explicitly agreed test borrower. No upgrade or keeper execution will be treated as approved until that review is complete.
