// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {LendingPool} from "../../src/core/ICFT/lending/LendingPool.sol";
import {PriceOracle} from "../../src/core/ICFT/oracle/PriceOracle.sol";
import {FutureOracleTimestamp} from "../../src/core/utils/Errors.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @notice Rehearses the V6 circuit-breaker upgrades under the live Safe + Timelock governance model.
contract SepoliaBorrowLimitUpgradeForkTest is Test {
    address internal constant TIMELOCK = 0xC4684C03F118c5D39F97f1F837132cEd65d947b1;
    address internal constant LENDING_POOL_PROXY = 0xAA34c13F7932eBb77dA286F35Dc95aA13CD7626A;
    address internal constant LENDING_POOL_PROXY_ADMIN = 0x362dD0ed3C1a5D983cb57703A6e73A5616f1526F;
    address internal constant ORACLE_PROXY = 0x59DD43D580A4aeBE84FdE44E748DB7F9CdA905a4;
    address internal constant ORACLE_PROXY_ADMIN = 0x0ff01511E1a9a1799df4AEdBb0d04F80Cf4f9CB6;
    address internal constant ETH_USD_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    function testFork_TimelockCanUpgradeAndInitializeV6CircuitBreakers() public {
        string memory rpcUrl = vm.envOr("SEPOLIA_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) return;

        vm.createSelectFork(rpcUrl);

        LendingPool pool = LendingPool(payable(LENDING_POOL_PROXY));
        assertEq(ProxyAdmin(LENDING_POOL_PROXY_ADMIN).owner(), TIMELOCK);
        assertEq(ProxyAdmin(ORACLE_PROXY_ADMIN).owner(), TIMELOCK);

        LendingPool implementation = new LendingPool();
        vm.prank(TIMELOCK);
        ProxyAdmin(LENDING_POOL_PROXY_ADMIN)
            .upgradeAndCall(
                ITransparentUpgradeableProxy(payable(LENDING_POOL_PROXY)), address(implementation), bytes("")
            );

        vm.prank(TIMELOCK);
        pool.initializeDynamicCircuitBreakersV6();

        assertEq(pool.maxBorrowPerTransactionBps(), 500);
        assertEq(pool.maxBorrowPerWindowBps(), 500);
        assertEq(pool.borrowWindowDuration(), 1 days);
        assertEq(pool.maxLiquidityWithdrawalPerWindowBps(), 500);
        assertEq(pool.liquidityWithdrawalWindowDuration(), 1 days);

        PriceOracle oracle = PriceOracle(ORACLE_PROXY);
        PriceOracle oracleImplementation = new PriceOracle();
        vm.prank(TIMELOCK);
        ProxyAdmin(ORACLE_PROXY_ADMIN)
            .upgradeAndCall(
                ITransparentUpgradeableProxy(payable(ORACLE_PROXY)), address(oracleImplementation), bytes("")
            );

        vm.mockCall(
            ETH_USD_FEED,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(uint80(1), int256(2_000e8), block.timestamp + 1, block.timestamp + 1, uint80(1))
        );
        vm.expectRevert(FutureOracleTimestamp.selector);
        oracle.getETHUSDPrice();
    }
}
