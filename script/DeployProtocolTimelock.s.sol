// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

interface ISafeOwners {
    function getOwners() external view returns (address[] memory);
    function getThreshold() external view returns (uint256);
}

/// @notice Deploys the protocol governance timelock controlled by a 2-of-3 Safe.
/// @dev This script does not move any protocol permissions. Handover happens only
///      after the deployed timelock has been independently verified on-chain.
contract DeployProtocolTimelock is Script {
    uint256 internal constant MINIMUM_DELAY = 1 days;

    function run() external returns (TimelockController timelock) {
        uint256 deployerPrivateKey = vm.envUint("TIMELOCK_DEPLOYER_PRIVATE_KEY");
        address safe = vm.envAddress("SAFE_ADDRESS");
        uint256 delay = vm.envOr("TIMELOCK_MIN_DELAY", MINIMUM_DELAY);

        _validateSafe(safe);
        require(delay >= MINIMUM_DELAY, "timelock delay below 24 hours");

        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = safe;
        executors[0] = safe;

        vm.startBroadcast(deployerPrivateKey);
        timelock = new TimelockController(delay, proposers, executors, safe);
        vm.stopBroadcast();

        require(timelock.getMinDelay() == delay, "unexpected timelock delay");
        require(timelock.hasRole(timelock.PROPOSER_ROLE(), safe), "Safe is not proposer");
        require(timelock.hasRole(timelock.EXECUTOR_ROLE(), safe), "Safe is not executor");
        require(timelock.hasRole(timelock.CANCELLER_ROLE(), safe), "Safe is not canceller");
        require(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), safe), "Safe is not timelock admin");

        console2.log("=== Protocol Timelock Summary ===");
        console2.log("safe", safe);
        console2.log("timelock", address(timelock));
        console2.log("minimum delay seconds", delay);
    }

    function _validateSafe(address safe) private view {
        require(safe.code.length != 0, "SAFE_ADDRESS has no contract code");

        ISafeOwners safeContract = ISafeOwners(safe);
        require(safeContract.getThreshold() == 2, "Safe threshold must be 2");

        address[] memory owners = safeContract.getOwners();
        require(owners.length == 3, "Safe must have exactly 3 owners");
        require(_contains(owners, vm.envAddress("SAFE_OWNER_1")), "Safe owner 1 missing");
        require(_contains(owners, vm.envAddress("SAFE_OWNER_2")), "Safe owner 2 missing");
        require(_contains(owners, vm.envAddress("SAFE_OWNER_3")), "Safe owner 3 missing");
    }

    function _contains(address[] memory owners, address owner) private pure returns (bool) {
        for (uint256 i; i < owners.length; ++i) {
            if (owners[i] == owner) return true;
        }
        return false;
    }
}
