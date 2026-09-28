// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {LendingPool} from "../src/core/ICFT/lending/LendingPool.sol";

/// @notice Prints the two Safe transactions required to apply the V6 security upgrade.
/// @dev Submit schedule calldata from the Safe, wait the Timelock delay, then submit execute calldata.
contract PrepareV6TimelockUpgrade is Script {
    bytes32 internal constant SALT = keccak256("ICFT_SEPOLIA_V6_DYNAMIC_CIRCUIT_BREAKERS");

    function run() external {
        address timelockAddress = vm.envAddress("TIMELOCK_ADDRESS");
        address lendingPoolProxy = vm.envAddress("LENDING_POOL_PROXY");
        address lendingPoolProxyAdmin = vm.envAddress("LENDING_POOL_PROXY_ADMIN");
        address oracleProxy = vm.envAddress("PRICE_ORACLE_PROXY");
        address oracleProxyAdmin = vm.envAddress("ORACLE_PROXY_ADMIN");
        address lendingPoolImplementation = vm.envAddress("V6_LENDING_POOL_IMPLEMENTATION");
        address oracleImplementation = vm.envAddress("V6_PRICE_ORACLE_IMPLEMENTATION");

        require(lendingPoolImplementation.code.length != 0, "LendingPool implementation not deployed");
        require(oracleImplementation.code.length != 0, "PriceOracle implementation not deployed");
        require(ProxyAdmin(lendingPoolProxyAdmin).owner() == timelockAddress, "pool ProxyAdmin not timelock-owned");
        require(ProxyAdmin(oracleProxyAdmin).owner() == timelockAddress, "oracle ProxyAdmin not timelock-owned");
        require(TimelockController(payable(timelockAddress)).getMinDelay() >= 1 days, "timelock delay below 24 hours");

        address[] memory targets = new address[](3);
        uint256[] memory values = new uint256[](3);
        bytes[] memory payloads = new bytes[](3);
        targets[0] = lendingPoolProxyAdmin;
        targets[1] = oracleProxyAdmin;
        targets[2] = lendingPoolProxy;
        payloads[0] = abi.encodeCall(
            ProxyAdmin.upgradeAndCall,
            (ITransparentUpgradeableProxy(payable(lendingPoolProxy)), lendingPoolImplementation, bytes(""))
        );
        payloads[1] = abi.encodeCall(
            ProxyAdmin.upgradeAndCall,
            (ITransparentUpgradeableProxy(payable(oracleProxy)), oracleImplementation, bytes(""))
        );
        payloads[2] = abi.encodeCall(LendingPool.initializeDynamicCircuitBreakersV6, ());

        TimelockController timelock = TimelockController(payable(timelockAddress));
        bytes memory scheduleCalldata = abi.encodeCall(
            TimelockController.scheduleBatch, (targets, values, payloads, bytes32(0), SALT, timelock.getMinDelay())
        );
        bytes memory executeCalldata =
            abi.encodeCall(TimelockController.executeBatch, (targets, values, payloads, bytes32(0), SALT));

        console2.log("=== Safe transaction 1: schedule V6 upgrade ===");
        console2.log("to", timelockAddress);
        console2.logBytes(scheduleCalldata);
        console2.log("=== Safe transaction 2: execute V6 upgrade after delay ===");
        console2.log("to", timelockAddress);
        console2.logBytes(executeCalldata);
        console2.log("operationId");
        console2.logBytes32(timelock.hashOperationBatch(targets, values, payloads, bytes32(0), SALT));
    }
}
