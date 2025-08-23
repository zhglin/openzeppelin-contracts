// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (utils/Pausable.sol)

pragma solidity ^0.8.20;

import {Context} from "../utils/Context.sol";

/**
 * @dev 合约模块，允许子合约实现一个可由授权帐户触发的紧急停止机制。
 *
 * 该模块通过继承来使用。它将提供 `whenNotPaused` 和 `whenPaused` 修改器，
 * 这些修改器可以应用于您的合约的函数。请注意，仅仅包含此模块并不会使函数变得可暂停，
 * 只有在应用了这些修改器之后才可以。
 * 
 * 此合约不包含公开的暂停和取消暂停功能。除了继承此合约外，您还必须定义这两个功能，调用 {Pausable-_pause} 和 {Pausable-_unpause}
  内部函数，并使用适当的访问控制...
 */
abstract contract Pausable is Context {
    bool private _paused;

    /**
     * @dev 当 `account` 触发暂停时发出。
     */
    event Paused(address account);

    /**
     * @dev 当 `account` 解除暂停时发出。
     */
    event Unpaused(address account);

    /**
     * @dev 操作失败，因为合约已被暂停。
     */
    error EnforcedPause();

    /**
     * @dev 操作失败，因为合约未被暂停。
     */
    error ExpectedPause();

    /**
     * @dev 修改器，使函数仅在合约未暂停时可调用。
     * 要求：
     * - 合约必须未被暂停。
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev 修改器，使函数仅在合约暂停时可调用。
     * 要求：
     * - 合约必须已被暂停。
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev 如果合约被暂停，则返回 true，否则返回 false。
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev 如果合约被暂停，则抛出错误。
     */
    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    /**
     * @dev 如果合约未被暂停，则抛出错误。
     */
    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    /**
     * @dev 触发停止状态。
     * 要求：
     * - 合约必须未被暂停。
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev 恢复到正常状态。
     * 要求：
     * - 合约必须已被暂停。
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}
