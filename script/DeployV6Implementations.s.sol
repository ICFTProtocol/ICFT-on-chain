// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {LendingPool} from "../src/core/ICFT/lending/LendingPool.sol";
import {PriceOracle} from "../src/core/ICFT/oracle/PriceOracle.sol";

/// @notice Deploys unprivileged V6 implementation contracts for a later Safe + Timelock upgrade.
/// @dev Deployment alone cannot alter protocol state or proxies.
contract DeployV6Implementations is Script {
    function run() external returns (address lendingPoolImplementation, address priceOracleImplementation) {
        uint256 deployerPrivateKey = vm.envUint("IMPLEMENTATION_DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        lendingPoolImplementation = address(new LendingPool());
        priceOracleImplementation = address(new PriceOracle());
        vm.stopBroadcast();

        console2.log("=== V6 Implementation Deployment ===");
        console2.log("lendingPoolImplementation", lendingPoolImplementation);
        console2.log("priceOracleImplementation", priceOracleImplementation);
    }
}
