// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (token/ERC6909/extensions/draft-ERC6909TokenSupply.sol)

pragma solidity ^0.8.20;

import {ERC6909} from "../draft-ERC6909.sol";
import {IERC6909TokenSupply} from "../../../interfaces/draft-IERC6909.sol";

/**
 * @dev ERC6909中定义的代币供应扩展的实现。
 * 单独跟踪每个代币id的总供应量。
 */
contract ERC6909TokenSupply is ERC6909, IERC6909TokenSupply {
    mapping(uint256 id => uint256) private _totalSupplies;

    /// @inheritdoc IERC6909TokenSupply
    function totalSupply(uint256 id) public view virtual override returns (uint256) {
        return _totalSupplies[id];
    }

    /// @dev 重写 `_update` 函数，以根据需要更新每个代币id的总供应量。
    function _update(address from, address to, uint256 id, uint256 amount) internal virtual override {
        super._update(from, to, id, amount);

        if (from == address(0)) {
            // 溢出会revoke
            _totalSupplies[id] += amount;
        }
        if (to == address(0)) {
            unchecked {
                // amount <= _balances[from][id] <= _totalSupplies[id]
                _totalSupplies[id] -= amount;
            }
        }
    }
}
