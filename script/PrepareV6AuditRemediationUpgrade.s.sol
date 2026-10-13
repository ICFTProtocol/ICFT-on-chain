// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @notice Prints the Safe schedule/execute calldata for the V6 audit-remediation pool upgrade.
/// @dev This upgrade has no initializer and must not be combined with unrelated governance actions.
contract PrepareV6AuditRemediationUpgrade is Script {
    bytes32 internal constant SALT = keccak256("ICFT_SEPOLIA_V6_AUDIT_REMEDIATION_2026_10");

    function run() external {
        address timelockAddress = vm.envAddress("TIMELOCK_ADDRESS");
        address lendingPoolProxy = vm.envAddress("LENDING_POOL_PROXY");
        address lendingPoolProxyAdmin = vm.envAddress("LENDING_POOL_PROXY_ADMIN");
        address implementation = vm.envAddress("V6_AUDIT_REMEDIATION_LENDING_POOL_IMPLEMENTATION");

        require(implementation.code.length != 0, "LendingPool implementation not deployed");
        require(ProxyAdmin(lendingPoolProxyAdmin).owner() == timelockAddress, "pool ProxyAdmin not timelock-owned");

        TimelockController timelock = TimelockController(payable(timelockAddress));
        require(timelock.getMinDelay() >= 1 days, "timelock delay below 24 hours");

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory payloads = new bytes[](1);
        targets[0] = lendingPoolProxyAdmin;
        payloads[0] = abi.encodeCall(
            ProxyAdmin.upgradeAndCall,
            (ITransparentUpgradeableProxy(payable(lendingPoolProxy)), implementation, bytes(""))
        );

        bytes memory scheduleCalldata = abi.encodeCall(
            TimelockController.scheduleBatch, (targets, values, payloads, bytes32(0), SALT, timelock.getMinDelay())
        );
        bytes memory executeCalldata =
            abi.encodeCall(TimelockController.executeBatch, (targets, values, payloads, bytes32(0), SALT));

        console2.log("=== Safe transaction 1: schedule V6 audit remediation ===");
        console2.log("to", timelockAddress);
        console2.logBytes(scheduleCalldata);
        console2.log("=== Safe transaction 2: execute after the timelock delay ===");
        console2.log("to", timelockAddress);
        console2.logBytes(executeCalldata);
        console2.log("operationId");
        console2.logBytes32(timelock.hashOperationBatch(targets, values, payloads, bytes32(0), SALT));
    }
}
