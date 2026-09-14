// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.30;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {ProtocolFixture} from "./helpers/ProtocolFixture.sol";
import {ICFTLiquidityVault} from "../src/core/ICFT/lending/ICFTLiquidityVault.sol";
import {BorrowBelowMinimum} from "../src/core/utils/Errors.sol";

contract LiquidityVaultAndBadDebtTest is ProtocolFixture {
    ICFTLiquidityVault internal vault;

    function setUp() public {
        _setUpProtocol();

        ICFTLiquidityVault implementation = new ICFTLiquidityVault();
        vault = ICFTLiquidityVault(
            address(
                new TransparentUpgradeableProxy(
                    address(implementation),
                    upgradeAdmin,
                    abi.encodeCall(ICFTLiquidityVault.initialize, (admin, address(lendingPool)))
                )
            )
        );

        lendingPool.grantRole(lendingPool.LP_VAULT_ROLE(), address(vault));
        vault.bootstrap(liquidity);
    }

    function testBootstrapMintsFundASharesToFundOwner() public view {
        assertTrue(vault.bootstrapped());
        assertEq(vault.balanceOf(liquidity), FUND_A);
        assertEq(vault.totalAssets(), FUND_A);
    }

    function testLpSupplyMintsSharesAndIncreasesPoolLiquidity() public {
        uint256 assets = 1_000 ether;
        uint256 sharesBefore = vault.balanceOf(alice);
        uint256 poolBalanceBefore = icft.balanceOf(address(lendingPool));

        vm.startPrank(alice);
        icft.approve(address(vault), assets);
        uint256 shares = vault.supply(assets, alice);
        vm.stopPrank();

        assertEq(shares, assets);
        assertEq(vault.balanceOf(alice), sharesBefore + shares);
        assertEq(icft.balanceOf(address(lendingPool)), poolBalanceBefore + assets);
        assertEq(lendingPool.fundALiquidityICFT(), FUND_A + assets);
    }

    function testInterestIsSplitBetweenLpAssetsAndInsuranceReserve() public {
        vm.startPrank(bob);
        lendingPool.depositCollateral{value: 1 ether}();
        lendingPool.borrow(1_000 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 365 days);
        ethFeed.setRoundData(2_000e8, block.timestamp);

        vm.prank(bob);
        lendingPool.repay(1_050 ether);

        assertEq(lendingPool.protocolRevenueICFT(), 7.5 ether);
        assertEq(vault.totalAssets(), FUND_A + 42.5 ether);
    }

    function testBadDebtClosesCollateralExhaustedPosition() public {
        vm.startPrank(alice);
        lendingPool.depositCollateral{value: 1 ether}();
        lendingPool.borrow(1_500 ether);
        vm.stopPrank();

        ethFeed.setRoundData(1_000e8, block.timestamp);
        uint256 debtBefore = lendingPool.getDebt(alice);

        vm.prank(liquidator);
        liquidationEngine.executeLiquidation(alice, NATIVE_ASSET, type(uint256).max, payable(liquidator));

        assertEq(lendingPool.getDebt(alice), 0);
        assertEq(lendingPool.getCollateralBalance(alice, NATIVE_ASSET), 0);
        assertGt(lendingPool.totalBadDebtUSD(), 0);
        assertLt(lendingPool.totalBadDebtUSD(), debtBefore);
        assertEq(lendingPool.totalBorrowedICFT(), 0);
    }

    function testUtilizationRetainsOtherBorrowerPrincipalAfterPriceMove() public {
        vm.startPrank(alice);
        lendingPool.depositCollateral{value: 1 ether}();
        lendingPool.borrow(100 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        lendingPool.depositCollateral{value: 1 ether}();
        lendingPool.borrow(100 ether);
        vm.stopPrank();

        oracle.setManualICFTPrice(5e7, 8);
        vm.prank(alice);
        lendingPool.repay(200 ether);

        assertEq(lendingPool.totalBorrowedICFT(), 100 ether);
    }

    function testBorrowRejectsConfiguredDustPosition() public {
        vm.prank(alice);
        lendingPool.depositCollateral{value: 1 ether}();

        vm.prank(alice);
        vm.expectRevert(BorrowBelowMinimum.selector);
        lendingPool.borrow(99 ether);
    }
}
