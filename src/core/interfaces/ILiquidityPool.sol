// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.30;

/// @notice Minimal pool surface used by the ICFT liquidity vault.
interface ILiquidityPool {
    function icft() external view returns (address);

    function getLPTotalAssets() external view returns (uint256);

    function supplyLiquidity(uint256 amount) external;

    function withdrawLiquidity(address recipient, uint256 amount) external;

    function accrueInterest() external;
}
