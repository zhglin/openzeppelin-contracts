// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/extensions/ERC20Capped.sol)

pragma solidity ^0.8.20;

import {ERC20} from "../ERC20.sol";

/**
 * @dev {ERC20} 的扩展，为代币的总供应量添加了一个上限。
 */
abstract contract ERC20Capped is ERC20 {
    uint256 private immutable _cap;

    /**
     * @dev 已超过总供应量上限。
     */
    error ERC20ExceededCap(uint256 increasedSupply, uint256 cap);

    /**
     * @dev 提供的上限值无效。
     */
    error ERC20InvalidCap(uint256 cap);

    /**
     * @dev 设置 `cap` 的值。这个值是不可变的，只能在构造函数中设置一次。
     */
    constructor(uint256 cap_) {
        if (cap_ == 0) {
            revert ERC20InvalidCap(0);
        }
        _cap = cap_;
    }

    /**
     * @dev 返回代币总供应量的上限。
     */
    function cap() public view virtual returns (uint256) {
        return _cap;
    }

    /// @inheritdoc ERC20
    function _update(address from, address to, uint256 value) internal virtual override {
        super._update(from, to, value);

        if (from == address(0)) {
            uint256 maxSupply = cap();
            uint256 supply = totalSupply();
            if (supply > maxSupply) {
                revert ERC20ExceededCap(supply, maxSupply);
            }
        }
    }
}
