// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {ICFTLiquidityVault} from "../src/core/ICFT/lending/ICFTLiquidityVault.sol";
import {LendingPool} from "../src/core/ICFT/lending/LendingPool.sol";

/// @notice Deploys and bootstraps the upgradeable ICFT LP receipt-token vault.
/// @dev The LendingPool must already run the audit-remediation implementation and contain Fund A ICFT.
contract DeployICFTLiquidityVault is Script {
    bytes32 internal constant ERC1967_ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function run() external returns (address vaultProxy) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address vaultAdmin = vm.envAddress("LP_VAULT_ADMIN_ADDRESS");
        address vaultUpgradeAdmin = vm.envAddress("LP_VAULT_UPGRADE_ADMIN_ADDRESS");
        address lendingPoolProxy = vm.envAddress("LENDING_POOL_PROXY");
        address initialLpOwner = vm.envAddress("LP_INITIAL_OWNER");

        vm.startBroadcast(deployerPrivateKey);

        ICFTLiquidityVault implementation = new ICFTLiquidityVault();
        vaultProxy = address(
            new TransparentUpgradeableProxy(
                address(implementation),
                vaultUpgradeAdmin,
                abi.encodeCall(ICFTLiquidityVault.initialize, (vaultAdmin, lendingPoolProxy))
            )
        );

        LendingPool lendingPool = LendingPool(payable(lendingPoolProxy));
        lendingPool.grantRole(lendingPool.LP_VAULT_ROLE(), vaultProxy);
        ICFTLiquidityVault(vaultProxy).bootstrap(initialLpOwner);

        vm.stopBroadcast();

        console2.log("=== ICFT Liquidity Vault Deployment Summary ===");
        console2.log("implementation", address(implementation));
        console2.log("proxy", vaultProxy);
        console2.log("proxyAdmin", _readProxyAdmin(vaultProxy));
        console2.log("lendingPool", lendingPoolProxy);
        console2.log("initialLpOwner", initialLpOwner);
    }

    function _readProxyAdmin(address proxy) internal view returns (address admin) {
        admin = address(uint160(uint256(vm.load(proxy, ERC1967_ADMIN_SLOT))));
    }
}
