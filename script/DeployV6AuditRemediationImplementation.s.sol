// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {LendingPool} from "../src/core/ICFT/lending/LendingPool.sol";

/// @notice Deploys the standalone LendingPool implementation for the V6 audit remediation.
/// @dev Deployment alone has no authority over the proxy or protocol state.
contract DeployV6AuditRemediationImplementation is Script {
    function run() external returns (address implementation) {
        uint256 deployerPrivateKey = vm.envUint("IMPLEMENTATION_DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        implementation = address(new LendingPool());
        vm.stopBroadcast();

        console2.log("v6AuditRemediationLendingPoolImplementation", implementation);
    }
}
