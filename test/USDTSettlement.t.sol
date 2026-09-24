// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.30;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {LendingPool} from "../src/core/ICFT/lending/LendingPool.sol";
import {USDTSettlementReserve} from "../src/core/ICFT/lending/USDTSettlementReserve.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {FeeOnTransferMockERC20} from "../src/mocks/FeeOnTransferMockERC20.sol";
import {InsufficientPendingSettlementUSDT, SettlementTransferMismatch} from "../src/core/utils/Errors.sol";
import {ProtocolFixture} from "./helpers/ProtocolFixture.sol";

/**
 * @title USDTSettlementTest
 * @notice Covers the optional USDT repayment rail for fixed-USD ICFT debt.
 * @dev These tests deliberately do not model a DEX. They prove that debt settlement, USDT custody,
 * and later ICFT credit-reserve restoration are separate, conservative accounting steps.
 */
contract USDTSettlementTest is ProtocolFixture {
    MockERC20 internal usdt;
    USDTSettlementReserve internal settlementReserve;

    function setUp() public {
        _setUpProtocol();

        usdt = new MockERC20("Test USD", "USDT", 6);
        USDTSettlementReserve reserveImplementation = new USDTSettlementReserve();
        settlementReserve = USDTSettlementReserve(
            address(
                new TransparentUpgradeableProxy(
                    address(reserveImplementation),
                    upgradeAdmin,
                    abi.encodeCall(USDTSettlementReserve.initialize, (admin, address(usdt), address(lendingPool)))
                )
            )
        );

        lendingPool.initializeUSDTSettlementV4(address(usdt), address(settlementReserve));
        settlementReserve.grantRole(settlementReserve.MARKET_EXECUTOR_ROLE(), admin);

        usdt.mint(alice, 10_000_000e6);
        vm.prank(alice);
        usdt.approve(address(lendingPool), type(uint256).max);
    }

    function testFullUSDTRepaymentSettlesDebtButDoesNotRestoreCreditInventory() public {
        _openOneHundredUSDDebt();
        uint256 liquidityAfterBorrow = lendingPool.fundALiquidityICFT();

        vm.prank(alice);
        lendingPool.repayWithUSDT(100e6);

        assertEq(lendingPool.getDebt(alice), 0, "USD debt should be closed");
        assertEq(usdt.balanceOf(address(settlementReserve)), 100e6, "reserve should custody USDT");
        assertEq(settlementReserve.pendingSettlementUSDT(), 100e6, "USDT should await market execution");
        assertEq(lendingPool.fundALiquidityICFT(), liquidityAfterBorrow, "no ICFT is restored before a market buy");
        assertEq(lendingPool.totalBorrowedICFT(), 0, "principal issuance should be cleared");
    }

    function testPartialUSDTRepaymentReducesDebtInUSD() public {
        _openOneHundredUSDDebt();

        vm.prank(alice);
        lendingPool.repayWithUSDT(25e6);

        assertEq(lendingPool.getDebt(alice), 75 ether, "partial USDT should reduce fixed USD debt");
        assertEq(settlementReserve.pendingSettlementUSDT(), 25e6, "only received USDT becomes pending");
        assertEq(lendingPool.totalBorrowedICFT(), 75 ether, "principal issuance should be reduced pro rata");
    }

    function testUSDTRepaymentCapsAtFullQuote() public {
        _openOneHundredUSDDebt();

        vm.prank(alice);
        lendingPool.repayWithUSDT(500e6);

        assertEq(usdt.balanceOf(address(settlementReserve)), 100e6, "pool must not pull an overpayment");
        assertEq(lendingPool.getDebt(alice), 0, "full debt should be closed");
    }

    function testFullUSDTQuoteRoundsUpAfterInterest() public {
        _openOneHundredUSDDebt();
        vm.warp(block.timestamp + 1 days);

        uint256 quote = lendingPool.getFullRepayUSDT(alice);
        assertGt(quote, 100e6, "quote should include accrued interest");

        vm.prank(alice);
        lendingPool.repayWithUSDT(quote);

        assertEq(lendingPool.getDebt(alice), 0, "rounded-up full quote must close all debt");
    }

    function testReserveCannotReleaseMoreUSDTThanPending() public {
        vm.expectRevert(InsufficientPendingSettlementUSDT.selector);
        settlementReserve.releaseForMarketPurchase(address(0xBEEF), 1);
    }

    function testMarketBoughtICFTRestoresCreditInventory() public {
        _openOneHundredUSDDebt();
        uint256 liquidityAfterBorrow = lendingPool.fundALiquidityICFT();

        vm.prank(alice);
        lendingPool.repayWithUSDT(100e6);

        vm.prank(liquidity);
        icft.transfer(address(settlementReserve), 100 ether);
        settlementReserve.replenishCreditReserveFromMarket(address(icft), 100 ether);

        assertEq(
            lendingPool.fundALiquidityICFT(), liquidityAfterBorrow + 100 ether, "bought ICFT restores Fund A inventory"
        );
        assertEq(icft.balanceOf(address(settlementReserve)), 0, "pool should pull returned ICFT");
    }

    function testFeeOnTransferSettlementTokenIsRejected() public {
        FeeOnTransferMockERC20 feeUSDT = new FeeOnTransferMockERC20();
        LendingPool feePool = _newPool();
        USDTSettlementReserve reserveImplementation = new USDTSettlementReserve();
        USDTSettlementReserve feeReserve = USDTSettlementReserve(
            address(
                new TransparentUpgradeableProxy(
                    address(reserveImplementation),
                    upgradeAdmin,
                    abi.encodeCall(USDTSettlementReserve.initialize, (admin, address(feeUSDT), address(feePool)))
                )
            )
        );
        feePool.initializeUSDTSettlementV4(address(feeUSDT), address(feeReserve));

        feeUSDT.mint(alice, 1_000 ether);
        vm.prank(alice);
        feeUSDT.approve(address(feePool), type(uint256).max);
        vm.prank(alice);
        feePool.depositCollateral{value: 1 ether}();
        vm.prank(alice);
        feePool.borrow(100 ether);

        vm.prank(alice);
        vm.expectRevert(SettlementTransferMismatch.selector);
        feePool.repayWithUSDT(100 ether);

        assertEq(feePool.getDebt(alice), 100 ether, "failed transfer must not reduce debt");
        assertEq(feeUSDT.balanceOf(address(feeReserve)), 0, "failed repayment must not leave settlement funds");
    }

    function _openOneHundredUSDDebt() internal {
        vm.prank(alice);
        lendingPool.depositCollateral{value: 1 ether}();
        vm.prank(alice);
        lendingPool.borrow(100 ether);
    }

    function _newPool() internal returns (LendingPool pool) {
        LendingPool implementation = new LendingPool();
        pool = LendingPool(
            payable(address(
                    new TransparentUpgradeableProxy(
                        address(implementation),
                        upgradeAdmin,
                        abi.encodeCall(
                            LendingPool.initialize,
                            (
                                admin,
                                address(icft),
                                address(oracle),
                                address(riskEngine),
                                address(rateModel),
                                FUND_A,
                                1_000 ether
                            )
                        )
                    )
                ))
        );

        vm.prank(liquidity);
        // The fixture has already distributed part of the fixed ICFT supply, and this isolated
        // pool needs only enough inventory to exercise a 100-ICFT loan.
        icft.transfer(address(pool), 100_000_000 ether);
    }
}
