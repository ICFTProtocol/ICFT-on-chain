// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {LendingPool} from "../src/core/ICFT/lending/LendingPool.sol";
import {PriceOracle} from "../src/core/ICFT/oracle/PriceOracle.sol";

/// @notice Prints Safe calldata to queue and execute the remaining V6 operational fixes.
contract PrepareV6OracleAndRoleRemediation is Script {
    uint256 internal constant TARGET_MAX_PRICE_AGE = 5_400;
    bytes32 internal constant SALT = keccak256("ICFT_SEPOLIA_V6_ORACLE_AND_ROLE_REMEDIATION");

    function run() external {
        address timelockAddress = vm.envAddress("TIMELOCK_ADDRESS");
        address poolAddress = vm.envAddress("LENDING_POOL_PROXY");
        address oracleAddress = vm.envAddress("PRICE_ORACLE_PROXY");
        address legacyLiquidationBot = vm.envAddress("LEGACY_LIQUIDATION_BOT");

        PriceOracle oracle = PriceOracle(oracleAddress);
        LendingPool pool = LendingPool(payable(poolAddress));
        TimelockController timelock = TimelockController(payable(timelockAddress));

        require(timelock.getMinDelay() >= 1 days, "timelock delay below 24 hours");
        require(
            oracle.hasRole(oracle.ORACLE_ADMIN_ROLE(), timelockAddress), "timelock lacks oracle admin role"
        );
        require(
            pool.hasRole(pool.DEFAULT_ADMIN_ROLE(), timelockAddress), "timelock lacks pool admin role"
        );
        require(
            pool.hasRole(pool.LIQUIDATION_BOT_ROLE(), legacyLiquidationBot), "legacy bot role already revoked"
        );

        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory payloads = new bytes[](2);
        targets[0] = oracleAddress;
        targets[1] = poolAddress;
        payloads[0] = abi.encodeCall(PriceOracle.setMaxPriceAge, (TARGET_MAX_PRICE_AGE));
        payloads[1] = abi.encodeWithSignature(
            "revokeRole(bytes32,address)", pool.LIQUIDATION_BOT_ROLE(), legacyLiquidationBot
        );

        bytes memory scheduleCalldata = abi.encodeCall(
            TimelockController.scheduleBatch, (targets, values, payloads, bytes32(0), SALT, timelock.getMinDelay())
        );
        bytes memory executeCalldata =
            abi.encodeCall(TimelockController.executeBatch, (targets, values, payloads, bytes32(0), SALT));

        console2.log("=== Safe transaction 1: schedule V6 oracle and role remediation ===");
        console2.log("to", timelockAddress);
        console2.logBytes(scheduleCalldata);
        console2.log("=== Safe transaction 2: execute after delay ===");
        console2.log("to", timelockAddress);
        console2.logBytes(executeCalldata);
        console2.log("operationId");
        console2.logBytes32(timelock.hashOperationBatch(targets, values, payloads, bytes32(0), SALT));
    }
}
