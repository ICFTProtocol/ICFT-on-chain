// SPDX-License-Identifier: GPL-3.0-only
/**
 * NOTICE
 *
 * ICFT is an upgradeable lending and programmable credit protocol developed
 * to let users borrow ICFT against on-chain collateral through transparent,
 * modular, and upgradeable smart contracts on EVM-compatible blockchains.
 *
 * Copyright (C) 2026, ICFT contributors.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */
pragma solidity 0.8.30;

/**
 * @title IUSDTSettlementReserve
 * @notice Receives USDT used to settle USD-denominated ICFT debt.
 * @dev The reserve does not price or execute DEX swaps itself. A separately authorized market executor
 * releases USDT only after a routing and slippage policy has been approved.
 *
 * @custom:version 1.0.0
 */
interface IUSDTSettlementReserve {
    /**
     * @notice Records a USDT repayment after the LendingPool has transferred the exact token amount here.
     * @param user Borrower whose USD debt was reduced.
     * @param amountUSDT USDT amount received using the token's native decimals.
     * @param repaidDebtUSD Total USD debt settled using 1e18 precision.
     * @param repaidPrincipalUSD USD principal portion of the settlement using 1e18 precision.
     * @param repaidInterestUSD USD interest portion of the settlement using 1e18 precision.
     */
    function recordSettlement(
        address user,
        uint256 amountUSDT,
        uint256 repaidDebtUSD,
        uint256 repaidPrincipalUSD,
        uint256 repaidInterestUSD
    ) external;

    /**
     * @notice Returns the ERC20 asset accepted for USD settlement.
     */
    function settlementAsset() external view returns (address);

    /**
     * @notice Returns the LendingPool authorized to record borrower settlements.
     */
    function lendingPool() external view returns (address);
}
