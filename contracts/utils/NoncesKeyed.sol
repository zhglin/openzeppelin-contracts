// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.2.0) (utils/NoncesKeyed.sol)
pragma solidity ^0.8.20;

import {Nonces} from "./Nonces.sol";

/**
 * @dev {Nonces} 的替代方案，支持带密钥（key-ed）的 nonces。
 *
 * 遵循 https://eips.ethereum.org/EIPS/eip-4337#semi-abstracted-nonce-support[ERC-4337 的半抽象 nonce 系统]。
 *
 * 注意：此合约继承自 {Nonces} 并为第一个 nonce 密钥（即 `0`）重用其存储。
 * 这使得在使用其可升级版本（例如 `NoncesKeyedUpgradeable`）时，从 {Nonces} 升级到 {NoncesKeyed} 是安全的。
 * 这样做不会重置 nonces 的当前状态，从而避免了在升级后因 nonce 重用而产生的重放攻击。
 */
abstract contract NoncesKeyed is Nonces {
    // key 是一个分类标识符，它让单个账户能够拥有多个独立的 nonce 序列，这是实现账户抽象中并行交易和灵活性的关键技术。
    // key 的类型是 uint192，因为它足够大，可以容纳大多数用例，同时仍然允许 nonce 作为 uint64 存储在单个 256 位存储槽中，从而节省了 gas 费用。
    // 这既是 ERC-4337 的标准要求，也是一种高效的数据处理方式。
    mapping(address owner => mapping(uint192 key => uint64)) private _nonces;

    /// @dev 返回一个地址和密钥的下一个未使用的 nonce。结果包含密钥前缀。
    function nonces(address owner, uint192 key) public view virtual returns (uint256) {
        return key == 0 ? nonces(owner) : _pack(key, _nonces[owner][key]);
    }

    /**
     * @dev 消耗一个地址和密钥的下一个未使用的 nonce。
     *
     * 返回不带密钥前缀的当前值。消耗的 nonce 会增加，因此使用相同参数两次调用此函数将返回不同的（连续的）结果。
     */
    function _useNonce(address owner, uint192 key) internal virtual returns (uint256) {
        // 对于每个账户，nonce 的初始值为0，只能加一，不能递减或重置。这保证了 nonce 永远不会溢出。
        unchecked {
            // 在这里执行 x++ 而不是 ++x 很重要。
            // 1. 首先，取出 _nonces[owner][key] 当前的值（例如，假设是 5），并将这个值（5）传递给 _pack 函数，用于生成本次操作要使用的 keyNonce。
            // 2. 然后，再将存储在 _nonces[owner][key] 的值加 1，使其变为 6，为下一次操作做准备。
            return key == 0 ? _useNonce(owner) : _pack(key, _nonces[owner][key]++);
        }
    }

    /**
     * @dev 与 {_useNonce} 相同，但会检查 `nonce` 是否是 `owner` 的下一个有效值。
     *
     * 此版本在单个 uint256 参数中接收密钥和 nonce：
     * - 前24个字节用于密钥
     * - 后8个字节用于 nonce
     */
    function _useCheckedNonce(address owner, uint256 keyNonce) internal virtual override {
        (uint192 key, ) = _unpack(keyNonce);
        if (key == 0) {
            super._useCheckedNonce(owner, keyNonce);
        } else {
            uint256 current = _useNonce(owner, key);
            if (keyNonce != current) revert InvalidAccountNonce(owner, current);
        }
    }

    /**
     * @dev 与 {_useNonce} 相同，但会检查 `nonce` 是否是 `owner` 的下一个有效值。
     *
     * 此版本将密钥和 nonce 作为两个不同的参数接收。
     */
    function _useCheckedNonce(address owner, uint192 key, uint64 nonce) internal virtual {
        _useCheckedNonce(owner, _pack(key, nonce));
    }

    /// @dev 将密钥和 nonce 打包成一个 keyNonce
    // * uint256(key) << 64：将192位的 key 左移64位，把它放置在一个256位空间的“高位”部分。
    // * | nonce：再通过“按位或”操作，将64位的 nonce 填充到这个256位空间的“低位”部分。
    // 最终形成一个 uint256 的结构：[ 192位的key | 64位的nonce ]
    function _pack(uint192 key, uint64 nonce) private pure returns (uint256) {
        return (uint256(key) << 64) | nonce;
    }

    /// @dev 将一个 keyNonce 解包成其密钥和 nonce 组件
    function _unpack(uint256 keyNonce) private pure returns (uint192 key, uint64 nonce) {
        return (uint192(keyNonce >> 64), uint64(keyNonce));
    }
}
