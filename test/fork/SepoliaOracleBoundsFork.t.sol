// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {PriceOracle} from "../../src/core/ICFT/oracle/PriceOracle.sol";
import {LendingPool} from "../../src/core/ICFT/lending/LendingPool.sol";
import {CollateralPriceBoundsNotConfigured, CollateralPriceOutOfBounds, UnsupportedCollateralAsset} from "../../src/core/utils/Errors.sol";

/// @notice Sepolia-only rehearsal for the oracle bounds upgrade. Never broadcasts a transaction.
contract SepoliaOracleBoundsForkTest is Test {
    address internal constant PROTOCOL_ADMIN = 0x6eA54179ba3004bc35cfAf6A67ddd9C6e5A1c6cc;
    address internal constant ORACLE_PROXY = 0x93CA63721859760c3688AddB3e61dfE2B1a4bE56;
    address internal constant ORACLE_PROXY_ADMIN = 0x7B07DB3898f2e63E8894966aA37C091968782241;
    address internal constant LENDING_POOL = 0x0F7933DC1FD07473e187dd5F278Bbdf10D73ECec;
    address internal constant WBTC = 0x29f2D40B0605204364af54EC677bD022dA425d03;
    address internal constant WSTETH = 0xB82381A3fBD3FaFA77B3a7bE693342618240067b;
    address internal constant WSTETH_USD_FEED = 0xbfFeA2aa76E356B2bD0a784783e882bb885F8438;

    function testFork_OracleBoundsUpgradeKeepsWstethDisabled() public {
        string memory rpcUrl = vm.envOr("SEPOLIA_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) return;

        vm.createSelectFork(rpcUrl);

        PriceOracle oracle = PriceOracle(ORACLE_PROXY);
        assertTrue(LendingPool(payable(LENDING_POOL)).paused());
        assertFalse(oracle.isCollateralAssetSupported(WSTETH));

        PriceOracle implementation = new PriceOracle();
        address upgradeOwner = ProxyAdmin(ORACLE_PROXY_ADMIN).owner();

        vm.prank(upgradeOwner);
        ProxyAdmin(ORACLE_PROXY_ADMIN).upgradeAndCall(
            ITransparentUpgradeableProxy(payable(ORACLE_PROXY)), address(implementation), ""
        );

        // Existing feeds are intentionally unusable until their bounds are explicitly approved.
        vm.expectRevert(abi.encodeWithSelector(CollateralPriceBoundsNotConfigured.selector, WBTC));
        oracle.getAssetUSDPrice(WBTC);

        vm.startPrank(PROTOCOL_ADMIN);
        oracle.setCollateralAssetPriceBounds(address(0), 500 ether, 10_000 ether);
        oracle.setCollateralAssetPriceBounds(WBTC, 10_000 ether, 250_000 ether);
        oracle.setCollateralAssetPriceBounds(WSTETH, 500 ether, 10_000 ether);
        vm.stopPrank();

        assertGt(oracle.getETHUSDPrice(), 500 ether);
        assertGt(oracle.getAssetUSDPrice(WBTC), 10_000 ether);
        assertFalse(oracle.isCollateralAssetSupported(WSTETH));

        // Model a fresh version of the incident answer. The live answer is stale, which is another
        // rejection path; this mock isolates and proves the new bounds check.
        vm.mockCall(
            WSTETH_USD_FEED,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(uint80(3), int256(10 ** 28), block.timestamp, block.timestamp, uint80(3))
        );
        vm.mockCall(
            WSTETH_USD_FEED, abi.encodeWithSelector(AggregatorV3Interface.decimals.selector), abi.encode(uint8(8))
        );

        // A feed with the Sepolia incident value cannot be re-enabled after the upgrade.
        vm.prank(PROTOCOL_ADMIN);
        vm.expectRevert(
            abi.encodeWithSelector(CollateralPriceOutOfBounds.selector, WSTETH, 10 ** 38, 500 ether, 10_000 ether)
        );
        oracle.setCollateralAssetFeed(WSTETH, WSTETH_USD_FEED, 18, true);

        vm.expectRevert(UnsupportedCollateralAsset.selector);
        oracle.getAssetUSDPrice(WSTETH);
    }
}
