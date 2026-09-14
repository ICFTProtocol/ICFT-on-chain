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
 */
pragma solidity 0.8.30;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ILiquidityPool} from "../../interfaces/ILiquidityPool.sol";
import {
    InvalidAddress,
    LiquidityVaultAlreadyBootstrapped,
    NoLiquidityAssets,
    ZeroAmount
} from "../../utils/Errors.sol";

/**
 * @title ICFTLiquidityVault
 * @notice Upgradeable ERC20 receipt-token vault for ICFT lending-pool liquidity providers.
 * @dev The share price reflects pool assets after insurance reserve is excluded and bad debt is written off.
 * @dev The initial Fund A owner receives bootstrap shares only after their ICFT has reached the LendingPool.
 *
 * @custom:version 2.0.0
 */
contract ICFTLiquidityVault is Initializable, ERC20Upgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant VAULT_ADMIN_ROLE = keccak256("VAULT_ADMIN_ROLE");

    IERC20 public asset;
    ILiquidityPool public lendingPool;
    bool public bootstrapped;
    uint256[48] private __gap;

    event LiquiditySupplied(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event LiquidityRedeemed(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event BootstrapCompleted(address indexed initialLp, uint256 initialAssets, uint256 initialShares);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the vault and approves its associated lending pool to pull ICFT deposits.
    /// @param admin Address receiving vault administration permissions.
    /// @param lendingPool_ Lending pool whose ICFT liquidity backs this vault's shares.
    function initialize(address admin, address lendingPool_) external initializer {
        if (admin == address(0) || lendingPool_ == address(0)) revert InvalidAddress();

        __ERC20_init("ICFT Lending Pool Share", "icftLP");
        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(VAULT_ADMIN_ROLE, admin);

        lendingPool = ILiquidityPool(lendingPool_);
        asset = IERC20(lendingPool.icft());
        asset.forceApprove(lendingPool_, type(uint256).max);
    }

    /// @notice Mints initial shares for Fund A after its ICFT inventory has been transferred into the pool.
    /// @param initialLp Address that should own the initial Fund A share position.
    function bootstrap(address initialLp) external onlyRole(VAULT_ADMIN_ROLE) nonReentrant {
        if (initialLp == address(0)) revert InvalidAddress();
        if (bootstrapped) revert LiquidityVaultAlreadyBootstrapped();

        lendingPool.accrueInterest();
        uint256 initialAssets = lendingPool.getLPTotalAssets();
        if (initialAssets == 0) revert NoLiquidityAssets();

        bootstrapped = true;
        _mint(initialLp, initialAssets);

        emit BootstrapCompleted(initialLp, initialAssets, initialAssets);
    }

    /// @notice Supplies ICFT and mints LP receipt shares at the current pool exchange rate.
    /// @param assets ICFT amount to supply.
    /// @param receiver Recipient of the minted icftLP shares.
    /// @return shares Number of receipt shares minted.
    function supply(uint256 assets, address receiver) external nonReentrant returns (uint256 shares) {
        if (!bootstrapped) revert NoLiquidityAssets();
        if (assets == 0) revert ZeroAmount();
        if (receiver == address(0)) revert InvalidAddress();

        lendingPool.accrueInterest();
        uint256 assetsBefore = lendingPool.getLPTotalAssets();
        if (assetsBefore == 0) revert NoLiquidityAssets();

        shares = (assets * totalSupply()) / assetsBefore;
        if (shares == 0) revert ZeroAmount();

        asset.safeTransferFrom(msg.sender, address(this), assets);
        lendingPool.supplyLiquidity(assets);
        _mint(receiver, shares);

        emit LiquiditySupplied(msg.sender, receiver, assets, shares);
    }

    /// @notice Burns receipt shares and withdraws the corresponding available ICFT liquidity.
    /// @param shares icftLP shares to burn.
    /// @param receiver Recipient of withdrawn ICFT.
    /// @return assets ICFT amount redeemed.
    function redeem(uint256 shares, address receiver) external nonReentrant returns (uint256 assets) {
        if (!bootstrapped) revert NoLiquidityAssets();
        if (shares == 0) revert ZeroAmount();
        if (receiver == address(0)) revert InvalidAddress();

        lendingPool.accrueInterest();
        assets = (shares * lendingPool.getLPTotalAssets()) / totalSupply();
        if (assets == 0) revert ZeroAmount();

        _burn(msg.sender, shares);
        lendingPool.withdrawLiquidity(address(this), assets);
        asset.safeTransfer(receiver, assets);

        emit LiquidityRedeemed(msg.sender, receiver, assets, shares);
    }

    /// @notice Returns the current ICFT asset value represented by one full share supply.
    function totalAssets() external view returns (uint256) {
        return lendingPool.getLPTotalAssets();
    }
}
