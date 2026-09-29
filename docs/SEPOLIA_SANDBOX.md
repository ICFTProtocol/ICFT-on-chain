# Sepolia Sandbox

The investor/demo deployment keeps a 24-hour timelock. Do not lower its delay.

Use a separate fresh deployment for rapid end-to-end testing. The sandbox may use
the same 2-of-3 Safe owners, but it must have separate proxies, ProxyAdmins,
and a separate TimelockController.

## Sandbox-only environment

Set these values in a local, untracked sandbox environment file:

```sh
ALLOW_SHORT_TESTNET_TIMELOCK=true
TIMELOCK_MIN_DELAY=300
```

The deployment and handover scripts reject a delay below 24 hours unless all of
the following are true: the explicit flag is set, the chain is Ethereum Sepolia
(`11155111`), and the delay is at least five minutes.

## Boundaries

- Never copy these two variables into the demo or production environment.
- Point a separate frontend preview deployment and monitor-only keeper instance
  at the sandbox addresses.
- Use the existing 24-hour demo deployment for investor demonstrations only.
