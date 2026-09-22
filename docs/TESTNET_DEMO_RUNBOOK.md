# ICFT Sepolia Demo Runbook

## Purpose

This runbook is the shared release checklist for developers, testers, and demo hosts. ICFT is an early testnet protocol, not a mainnet financial product.

## Components

| Component | Repository | Role |
| --- | --- | --- |
| Smart contracts | `ICFT-on-chain` | Upgradeable lending, risk, oracle, liquidation, and LP-vault contracts. |
| Frontend | `ICFT_Frontend` | Public site and wallet-connected Sepolia dApp. |
| Keeper | `ICFT_Backend_Bot` | Private dry-run liquidation monitoring worker. |

## Demo Preconditions

1. `forge test` passes in the contracts repository.
2. `npm run build` passes in the frontend and keeper repositories.
3. Frontend environment contains only public `NEXT_PUBLIC_*` values and valid Sepolia proxy addresses.
4. The keeper has `EXECUTION_ENABLED=false`.
5. Two dedicated test wallets are funded: one with ICFT for the LP flow and one with Sepolia ETH for collateral and gas.
6. No administrator, deployer, treasury, or mainnet wallet is connected to the public dApp during a demo.

## Demo Sequence

1. Show `/status` and the Ethereum Sepolia network.
2. LP: supply a small ICFT amount, then redeem a small `icftLP` amount.
3. Borrower: deposit ETH, borrow at least the `$100` minimum, partially repay, fully repay, then withdraw ETH.
4. Demonstrate the intentional unsafe-withdraw revert while debt is active.
5. Show the keeper log and state file indexing the borrower. No liquidation candidate is expected for a healthy position.

## Do Not Claim

- Mainnet readiness or audited production security.
- A live ICFT market, automatic buyback, burn, market making, or price stability.
- Autonomous profitable liquidations. The keeper currently monitors in dry-run mode.
- Public faucet availability for the configured wBTC/wstETH test assets.

## Incident Response

- A frontend issue: stop sharing the deployment URL, capture the browser error and transaction hash, then roll back the Vercel deployment.
- An incorrect public environment value: replace it in Vercel and redeploy; never put a secret in `NEXT_PUBLIC_*` variables.
- A keeper issue: stop the worker. It has no execution authority in dry-run mode.
- A contract issue: pause the affected contract only with the authorised admin process; do not attempt an ad-hoc upgrade during a public demo.
