// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";

import {PriceOracle} from "../../src/core/ICFT/oracle/PriceOracle.sol";

/// @notice Verifies that the clean Sepolia oracle rejects the legacy public-price-setter attack.
contract SepoliaOracleAccessControlForkTest is Test {
    address internal constant CLEAN_ORACLE_PROXY = 0x59DD43D580A4aeBE84FdE44E748DB7F9CdA905a4;
    address internal constant LEGACY_ATTACKER = 0x301eDb930dC761766e1F4A00f0fc532AFEbd5bB4;

    function testFork_UnauthorizedAccountCannotSetManualICFTPrice() public {
        string memory rpcUrl = vm.envOr("SEPOLIA_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) return;

        vm.createSelectFork(rpcUrl);

        PriceOracle oracle = PriceOracle(CLEAN_ORACLE_PROXY);
        bytes32 oracleAdminRole = oracle.ORACLE_ADMIN_ROLE();
        assertFalse(oracle.hasRole(oracleAdminRole, LEGACY_ATTACKER));

        vm.prank(LEGACY_ATTACKER);
        vm.expectRevert();
        oracle.setManualICFTPrice(1, 8);
    }
}
