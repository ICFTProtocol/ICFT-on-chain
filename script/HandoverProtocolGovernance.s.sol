// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

interface IAccessControlTarget {
    function hasRole(bytes32 role, address account) external view returns (bool);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
}

interface ITimelockDelay {
    function getMinDelay() external view returns (uint256);
}

/// @notice One-time bootstrap handover from the deployment EOA to Safe + Timelock.
/// @dev Configuration and upgrades become 2-of-3 Safe proposals with a 24h delay.
///      The Safe receives only LendingPool's emergency pauser role. Liquidation
///      operator roles are intentionally not changed by this governance handover.
contract HandoverProtocolGovernance is Script {
    bytes32 internal constant DEFAULT_ADMIN_ROLE = bytes32(0);
    bytes32 internal constant ORACLE_ADMIN_ROLE = keccak256("ORACLE_ADMIN_ROLE");
    bytes32 internal constant RATE_ADMIN_ROLE = keccak256("RATE_ADMIN_ROLE");
    bytes32 internal constant RISK_ADMIN_ROLE = keccak256("RISK_ADMIN_ROLE");
    bytes32 internal constant CONFIG_ADMIN_ROLE = keccak256("CONFIG_ADMIN_ROLE");
    bytes32 internal constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 internal constant ENGINE_ADMIN_ROLE = keccak256("ENGINE_ADMIN_ROLE");
    uint256 internal constant MINIMUM_DELAY = 1 days;
    uint256 internal constant MINIMUM_SANDBOX_DELAY = 5 minutes;
    uint256 internal constant SEPOLIA_CHAIN_ID = 11_155_111;

    struct Config {
        address currentAdmin;
        address safe;
        address timelock;
        address priceOracle;
        address interestRateModel;
        address riskEngine;
        address lendingPool;
        address liquidationEngine;
        address[6] proxyAdmins;
    }

    function run() external {
        uint256 bootstrapPrivateKey = vm.envUint("GOVERNANCE_BOOTSTRAP_PRIVATE_KEY");
        Config memory config = _loadConfig();
        require(vm.addr(bootstrapPrivateKey) == config.currentAdmin, "bootstrap key is not current admin");
        _validatePreconditions(config);

        vm.startBroadcast(bootstrapPrivateKey);

        _handoverConfigRole(config.priceOracle, ORACLE_ADMIN_ROLE, config);
        _handoverConfigRole(config.interestRateModel, RATE_ADMIN_ROLE, config);
        _handoverConfigRole(config.riskEngine, RISK_ADMIN_ROLE, config);
        _handoverPool(config);
        _handoverConfigRole(config.liquidationEngine, ENGINE_ADMIN_ROLE, config);

        for (uint256 i; i < config.proxyAdmins.length; ++i) {
            ProxyAdmin(config.proxyAdmins[i]).transferOwnership(config.timelock);
        }

        vm.stopBroadcast();
        _verifyHandover(config);

        console2.log("=== Protocol Governance Handover Complete ===");
        console2.log("safe emergency pauser", config.safe);
        console2.log("timelock configuration and upgrade owner", config.timelock);
    }

    function _loadConfig() private view returns (Config memory config) {
        config.currentAdmin = vm.envAddress("CURRENT_PROTOCOL_ADMIN");
        config.safe = vm.envAddress("SAFE_ADDRESS");
        config.timelock = vm.envAddress("TIMELOCK_ADDRESS");
        config.priceOracle = vm.envAddress("PRICE_ORACLE_PROXY");
        config.interestRateModel = vm.envAddress("INTEREST_RATE_MODEL_PROXY");
        config.riskEngine = vm.envAddress("RISK_ENGINE_PROXY");
        config.lendingPool = vm.envAddress("LENDING_POOL_PROXY");
        config.liquidationEngine = vm.envAddress("LIQUIDATION_ENGINE_PROXY");
        config.proxyAdmins[0] = vm.envAddress("ICFT_PROXY_ADMIN");
        config.proxyAdmins[1] = vm.envAddress("ORACLE_PROXY_ADMIN");
        config.proxyAdmins[2] = vm.envAddress("RATE_MODEL_PROXY_ADMIN");
        config.proxyAdmins[3] = vm.envAddress("RISK_ENGINE_PROXY_ADMIN");
        config.proxyAdmins[4] = vm.envAddress("LENDING_POOL_PROXY_ADMIN");
        config.proxyAdmins[5] = vm.envAddress("LIQUIDATION_ENGINE_PROXY_ADMIN");
    }

    function _validatePreconditions(Config memory config) private view {
        require(config.safe.code.length != 0, "Safe is not deployed");
        require(config.timelock.code.length != 0, "Timelock is not deployed");
        _validateTimelockDelay(ITimelockDelay(config.timelock).getMinDelay());

        _requireAdmin(config.priceOracle, config.currentAdmin);
        _requireAdmin(config.interestRateModel, config.currentAdmin);
        _requireAdmin(config.riskEngine, config.currentAdmin);
        _requireAdmin(config.lendingPool, config.currentAdmin);
        _requireAdmin(config.liquidationEngine, config.currentAdmin);

        for (uint256 i; i < config.proxyAdmins.length; ++i) {
            require(ProxyAdmin(config.proxyAdmins[i]).owner() == config.currentAdmin, "unexpected ProxyAdmin owner");
        }
    }

    function _handoverConfigRole(address target, bytes32 configRole, Config memory config) private {
        IAccessControlTarget access = IAccessControlTarget(target);
        access.grantRole(DEFAULT_ADMIN_ROLE, config.timelock);
        access.grantRole(configRole, config.timelock);
        access.revokeRole(configRole, config.currentAdmin);
        access.revokeRole(DEFAULT_ADMIN_ROLE, config.currentAdmin);
    }

    function _handoverPool(Config memory config) private {
        IAccessControlTarget pool = IAccessControlTarget(config.lendingPool);
        pool.grantRole(DEFAULT_ADMIN_ROLE, config.timelock);
        pool.grantRole(CONFIG_ADMIN_ROLE, config.timelock);
        pool.grantRole(PAUSER_ROLE, config.safe);
        pool.revokeRole(CONFIG_ADMIN_ROLE, config.currentAdmin);
        pool.revokeRole(PAUSER_ROLE, config.currentAdmin);
        pool.revokeRole(DEFAULT_ADMIN_ROLE, config.currentAdmin);
    }

    function _verifyHandover(Config memory config) private view {
        _verifyConfigRole(config.priceOracle, ORACLE_ADMIN_ROLE, config);
        _verifyConfigRole(config.interestRateModel, RATE_ADMIN_ROLE, config);
        _verifyConfigRole(config.riskEngine, RISK_ADMIN_ROLE, config);
        _verifyConfigRole(config.lendingPool, CONFIG_ADMIN_ROLE, config);
        _verifyConfigRole(config.liquidationEngine, ENGINE_ADMIN_ROLE, config);

        IAccessControlTarget pool = IAccessControlTarget(config.lendingPool);
        require(pool.hasRole(PAUSER_ROLE, config.safe), "Safe missing pauser role");
        require(!pool.hasRole(PAUSER_ROLE, config.currentAdmin), "old admin still pauser");

        for (uint256 i; i < config.proxyAdmins.length; ++i) {
            require(ProxyAdmin(config.proxyAdmins[i]).owner() == config.timelock, "ProxyAdmin transfer failed");
        }
    }

    function _requireAdmin(address target, address currentAdmin) private view {
        require(IAccessControlTarget(target).hasRole(DEFAULT_ADMIN_ROLE, currentAdmin), "current admin role missing");
    }

    function _verifyConfigRole(address target, bytes32 role, Config memory config) private view {
        IAccessControlTarget access = IAccessControlTarget(target);
        require(access.hasRole(DEFAULT_ADMIN_ROLE, config.timelock), "timelock missing admin role");
        require(access.hasRole(role, config.timelock), "timelock missing config role");
        require(!access.hasRole(DEFAULT_ADMIN_ROLE, config.currentAdmin), "old default admin remains");
        require(!access.hasRole(role, config.currentAdmin), "old config admin remains");
    }

    /// @dev Keeps the production handover at 24h while enabling an explicit Sepolia-only sandbox path.
    function _validateTimelockDelay(uint256 delay) private view {
        if (delay >= MINIMUM_DELAY) return;

        require(vm.envOr("ALLOW_SHORT_TESTNET_TIMELOCK", false), "short delay flag missing");
        require(block.chainid == SEPOLIA_CHAIN_ID, "short delay only on Sepolia");
        require(delay >= MINIMUM_SANDBOX_DELAY, "sandbox delay below 5 minutes");
    }
}
