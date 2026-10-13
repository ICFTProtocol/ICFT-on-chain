# V6 Audit Remediation Upgrade

## Scope

This release changes only the public V6 LendingPool implementation:

- LP total assets use protocol accounting, so unsolicited ICFT transfers cannot inflate LP share value.
- A disabled ERC20 collateral asset may be removed once the pool holds none of that token.
- Debt-free collateral withdrawal does not call a collateral oracle.
- Borrow and withdrawal health checks compare exact USD debt against the exact allowed USD debt.

It does not include sandbox/V7/V8 changes, does not add storage variables, and has no initializer.

## Required Review Before Deployment

1. Run `forge test` and `forge build --sizes` from this branch.
2. Compare `forge inspect LendingPool storageLayout` with the deployed V6 source. The layout must be identical.
3. Review the deployed implementation bytecode and the prospective implementation on Sepolia.
4. Run the fork rehearsal and obtain auditor approval of the implementation address and Safe calldata.

## Deployment

Use a dedicated implementation-deployer wallet with Sepolia ETH. Never paste its private key into chat or commit it.

```bash
source ../FND/.env
read -rs "IMPLEMENTATION_DEPLOYER_PRIVATE_KEY?Implementation deployer private key: "
echo
export IMPLEMENTATION_DEPLOYER_PRIVATE_KEY

forge script script/DeployV6AuditRemediationImplementation.s.sol:DeployV6AuditRemediationImplementation \
  --rpc-url "$RPC_URL" \
  --broadcast \
  -vvvv

unset IMPLEMENTATION_DEPLOYER_PRIVATE_KEY
```

Record the printed implementation address. Then generate Safe calldata without broadcasting:

```bash
export TIMELOCK_ADDRESS=0xC4684C03F118c5D39F97f1F837132cEd65d947b1
export LENDING_POOL_PROXY=0xAA34c13F7932eBb77dA286F35Dc95aA13CD7626A
export LENDING_POOL_PROXY_ADMIN=0x362dD0ed3C1a5D983cb57703A6e73A5616f1526f
export V6_AUDIT_REMEDIATION_LENDING_POOL_IMPLEMENTATION=<new-implementation-address>

forge script script/PrepareV6AuditRemediationUpgrade.s.sol:PrepareV6AuditRemediationUpgrade \
  --rpc-url "$RPC_URL" \
  -vvvv
```

Create the printed `scheduleBatch` transaction in Safe, collect two signatures, and execute it. Wait the existing 24-hour Timelock delay. Then create and execute the printed `executeBatch` transaction with two Safe signatures.

## Post-Upgrade Checks

1. Confirm the LendingPool proxy implementation changed to the reviewed address.
2. Run the four remediation tests against Sepolia: direct ICFT donation, disabled-asset removal, debt-free withdrawal with stale oracle, and exact-LTV boundary.
3. Re-run the keeper health check and one deliberately unsafe liquidation only after Stas approves the target scenario.
