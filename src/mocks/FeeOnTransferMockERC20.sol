// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Test-only ERC20 that charges a transfer fee to validate pool collateral accounting.
contract FeeOnTransferMockERC20 is ERC20 {
    uint256 public constant FEE_BPS = 100;
    uint256 public constant BPS = 10_000;

    constructor() ERC20("Fee collateral", "FEE") {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from == address(0) || to == address(0)) {
            super._update(from, to, value);
            return;
        }

        uint256 fee = (value * FEE_BPS) / BPS;
        super._update(from, to, value - fee);
        super._update(from, address(0), fee);
    }
}
