// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {LendingPool} from "../../src/core/ICFT/lending/LendingPool.sol";

/// @notice Rehearses the LendingPool V5 borrow-limit upgrade against the clean Sepolia proxy.
contract SepoliaBorrowLimitUpgradeForkTest is Test {
    address internal constant PROTOCOL_ADMIN = 0x6eA54179ba3004bc35cfAf6A67ddd9C6e5A1c6cc;
    address internal constant LENDING_POOL_PROXY = 0xAA34c13F7932eBb77dA286F35Dc95aA13CD7626A;
    address internal constant LENDING_POOL_PROXY_ADMIN = 0x362dD0ed3C1a5D983cb57703A6e73A5616f1526F;

    function testFork_UpgradeInitializesBorrowCircuitBreakers() public {
        string memory rpcUrl = vm.envOr("SEPOLIA_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) return;

        vm.createSelectFork(rpcUrl);

        LendingPool pool = LendingPool(payable(LENDING_POOL_PROXY));
        assertEq(ProxyAdmin(LENDING_POOL_PROXY_ADMIN).owner(), PROTOCOL_ADMIN);
        assertEq(pool.totalBorrowedICFT(), 0);
        assertEq(pool.totalScaledDebtUSD(), 0);

        vm.prank(PROTOCOL_ADMIN);
        pool.pause();

        LendingPool implementation = new LendingPool();
        vm.prank(PROTOCOL_ADMIN);
        ProxyAdmin(LENDING_POOL_PROXY_ADMIN).upgradeAndCall(
            ITransparentUpgradeableProxy(payable(LENDING_POOL_PROXY)), address(implementation), bytes("")
        );

        vm.prank(PROTOCOL_ADMIN);
        pool.initializeBorrowLimitV5();

        assertEq(pool.maxBorrowPerTransactionBps(), 500);
        assertEq(pool.maxBorrowPerWindowBps(), 500);
        assertEq(pool.borrowWindowDuration(), 1 days);
        assertTrue(pool.paused());
    }
}
