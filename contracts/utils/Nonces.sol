// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Nonces.sol)
pragma solidity ^0.8.20;

/**
 * @dev 为地址提供 nonce（随机数）追踪功能。Nonce 值只会递增。
 */
abstract contract Nonces {
    /**
     * @dev 用于 `account` 的 nonce 不是预期的当前 nonce。
     */
    error InvalidAccountNonce(address account, uint256 currentNonce);

    mapping(address account => uint256) private _nonces;

    /**
     * @dev 返回一个地址的下一个未使用的 nonce。
     */
    function nonces(address owner) public view virtual returns (uint256) {
        return _nonces[owner];
    }

    /**
     * @dev 使用一个 nonce。
     * 返回当前值并递增 nonce。
     */
    function _useNonce(address owner) internal virtual returns (uint256) {
        // 对于每个账户，nonce 的初始值为 0，只能加一递增，不能减少或重置。
        // 这保证了 nonce 永远不会溢出。
        unchecked {
            // 在这里使用 x++ 而不是 ++x 非常重要。
            return _nonces[owner]++;
        }
    }

    /**
     * @dev 与 {_useNonce} 相同，但会检查 `nonce` 是否是 `owner` 的下一个有效 nonce。
     */
    function _useCheckedNonce(address owner, uint256 nonce) internal virtual {
        uint256 current = _useNonce(owner);
        if (nonce != current) {
            revert InvalidAccountNonce(owner, current);
        }
    }
}
