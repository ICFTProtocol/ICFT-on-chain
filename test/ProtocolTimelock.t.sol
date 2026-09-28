// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract ProtocolTimelockTest is Test {
    address internal constant SAFE = address(0xBEEF);

    function testSafeIsSoleGovernanceActorAndDelayIsOneDay() public {
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = SAFE;
        executors[0] = SAFE;

        TimelockController timelock = new TimelockController(1 days, proposers, executors, SAFE);

        assertEq(timelock.getMinDelay(), 1 days);
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), SAFE));
        assertTrue(timelock.hasRole(timelock.EXECUTOR_ROLE(), SAFE));
        assertTrue(timelock.hasRole(timelock.CANCELLER_ROLE(), SAFE));
        assertTrue(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), SAFE));
        assertFalse(timelock.hasRole(timelock.PROPOSER_ROLE(), address(this)));
        assertFalse(timelock.hasRole(timelock.EXECUTOR_ROLE(), address(this)));
    }
}
