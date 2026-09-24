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

import {Script, console2} from "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {USDTSettlementReserve} from "../src/core/ICFT/lending/USDTSettlementReserve.sol";

/**
 * @title DeployUSDTSettlementReserve
 * @notice Deploys the upgradeable reserve used by the optional USDT debt-settlement rail.
 * @dev This deploys only the reserve. Upgrade LendingPool separately with `UpgradeICFTModule` and
 * `initializeUSDTSettlementV4(asset,reserve)` after a storage-layout and fork rehearsal review.
 */
contract DeployUSDTSettlementReserve is Script {
    /**
     * @notice Deploys the reserve proxy and grants the configured market executor its limited role.
     * @return reserveProxy Address of the newly deployed USDTSettlementReserve proxy.
     */
    function run() external returns (address reserveProxy) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address reserveAdmin = vm.envAddress("USDT_SETTLEMENT_ADMIN");
        address reserveUpgradeAdmin = vm.envAddress("USDT_SETTLEMENT_UPGRADE_ADMIN");
        address settlementAsset = vm.envAddress("USDT_SETTLEMENT_ASSET");
        address lendingPool = vm.envAddress("LENDING_POOL_PROXY");
        address marketExecutor = vm.envAddress("USDT_MARKET_EXECUTOR");

        vm.startBroadcast(deployerPrivateKey);

        USDTSettlementReserve implementation = new USDTSettlementReserve();
        reserveProxy = address(
            new TransparentUpgradeableProxy(
                address(implementation),
                reserveUpgradeAdmin,
                abi.encodeCall(USDTSettlementReserve.initialize, (reserveAdmin, settlementAsset, lendingPool))
            )
        );

        USDTSettlementReserve(reserveProxy)
            .grantRole(USDTSettlementReserve(reserveProxy).MARKET_EXECUTOR_ROLE(), marketExecutor);

        vm.stopBroadcast();

        console2.log("=== USDT Settlement Reserve Deployment Summary ===");
        console2.log("reserve implementation", address(implementation));
        console2.log("reserve proxy", reserveProxy);
        console2.log("settlement asset", settlementAsset);
        console2.log("lending pool", lendingPool);
        console2.log("reserve admin", reserveAdmin);
        console2.log("market executor", marketExecutor);
    }
}
