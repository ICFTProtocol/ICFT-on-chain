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

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IUSDTSettlementReserve} from "../../interfaces/IUSDTSettlementReserve.sol";
import {ILendingPool} from "../../interfaces/ILendingPool.sol";
import {
    InvalidAddress,
    InsufficientPendingSettlementUSDT,
    SettlementTransferMismatch,
    ZeroAmount
} from "../../utils/Errors.sol";

/**
 * @title USDTSettlementReserve
 * @notice Custodies USDT received from USD-denominated loan repayments before approved market execution.
 * @dev This module intentionally has no embedded DEX router. Market execution must be separately reviewed,
 * slippage-limited, and operated through a narrowly scoped executor role.
 *
 * @custom:version 1.0.0
 */
contract USDTSettlementReserve is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    IUSDTSettlementReserve
{
    using SafeERC20 for IERC20;

    bytes32 public constant RESERVE_ADMIN_ROLE = keccak256("RESERVE_ADMIN_ROLE");
    bytes32 public constant MARKET_EXECUTOR_ROLE = keccak256("MARKET_EXECUTOR_ROLE");

    IERC20 internal settlementToken;
    address public override lendingPool;
    uint256 public pendingSettlementUSDT;
    uint256 public totalSettledUSDT;
    uint256 public totalReleasedUSDT;
    uint256[45] private __gap;

    event USDTSettlementRecorded(
        address indexed user,
        uint256 amountUSDT,
        uint256 repaidDebtUSD,
        uint256 repaidPrincipalUSD,
        uint256 repaidInterestUSD
    );
    event USDTReleasedForMarketPurchase(address indexed executor, address indexed recipient, uint256 amountUSDT);
    event CreditReserveReplenished(address indexed executor, address indexed icftAsset, uint256 amountICFT);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the reserve with its USDT asset and the only LendingPool allowed to record settlement.
     * @param admin Address receiving reserve administration permissions.
     * @param settlementAsset_ USDT-compatible ERC20 token accepted by the current protocol deployment.
     * @param lendingPool_ LendingPool that receives borrower repayment requests.
     */
    function initialize(address admin, address settlementAsset_, address lendingPool_) external initializer {
        if (admin == address(0) || settlementAsset_ == address(0) || lendingPool_ == address(0)) {
            revert InvalidAddress();
        }

        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(RESERVE_ADMIN_ROLE, admin);

        settlementToken = IERC20(settlementAsset_);
        lendingPool = lendingPool_;
    }

    /**
     * @inheritdoc IUSDTSettlementReserve
     */
    function recordSettlement(
        address user,
        uint256 amountUSDT,
        uint256 repaidDebtUSD,
        uint256 repaidPrincipalUSD,
        uint256 repaidInterestUSD
    ) external override nonReentrant {
        if (msg.sender != lendingPool) revert InvalidAddress();
        if (user == address(0) || amountUSDT == 0 || repaidDebtUSD == 0) revert ZeroAmount();

        // The pool transfers first. This prevents accounting a settlement that never reached custody.
        if (settlementToken.balanceOf(address(this)) < pendingSettlementUSDT + amountUSDT) {
            revert SettlementTransferMismatch();
        }

        pendingSettlementUSDT += amountUSDT;
        totalSettledUSDT += amountUSDT;

        emit USDTSettlementRecorded(user, amountUSDT, repaidDebtUSD, repaidPrincipalUSD, repaidInterestUSD);
    }

    /**
     * @notice Releases pending settlement USDT to an approved market-execution destination.
     * @dev This function never performs a swap. The executor must enforce approved router, route, quote,
     * deadline, and slippage constraints in the execution layer before calling it.
     * @param recipient Approved market-execution recipient.
     * @param amountUSDT Exact USDT amount to release using native token decimals.
     */
    function releaseForMarketPurchase(address recipient, uint256 amountUSDT)
        external
        nonReentrant
        onlyRole(MARKET_EXECUTOR_ROLE)
    {
        if (recipient == address(0)) revert InvalidAddress();
        if (amountUSDT == 0) revert ZeroAmount();
        if (amountUSDT > pendingSettlementUSDT) revert InsufficientPendingSettlementUSDT();

        pendingSettlementUSDT -= amountUSDT;
        totalReleasedUSDT += amountUSDT;
        settlementToken.safeTransfer(recipient, amountUSDT);

        emit USDTReleasedForMarketPurchase(msg.sender, recipient, amountUSDT);
    }

    /**
     * @notice Returns ICFT bought by an approved market executor to the LendingPool credit reserve.
     * @dev The LendingPool pulls its own canonical ICFT token from this reserve. Supplying another token
     * address cannot replenish pool liquidity because the pool verifies the transferred token by design.
     * @param icftAsset Canonical ICFT ERC20 address configured in the LendingPool.
     * @param amountICFT Exact ICFT amount to return to Fund A inventory.
     */
    function replenishCreditReserveFromMarket(address icftAsset, uint256 amountICFT)
        external
        nonReentrant
        onlyRole(MARKET_EXECUTOR_ROLE)
    {
        if (icftAsset == address(0)) revert InvalidAddress();
        if (amountICFT == 0) revert ZeroAmount();

        IERC20(icftAsset).forceApprove(lendingPool, amountICFT);
        ILendingPool(lendingPool).replenishCreditReserveFromMarket(amountICFT);

        emit CreditReserveReplenished(msg.sender, icftAsset, amountICFT);
    }

    /**
     * @notice Returns the ERC20 settlement asset accepted by this reserve.
     */
    function settlementAsset() external view override returns (address) {
        return address(settlementToken);
    }
}
