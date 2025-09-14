// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (access/Ownable2Step.sol)

pragma solidity ^0.8.20;

import {Ownable} from "./Ownable.sol";

/**
 * @dev 合约模块，提供访问控制机制，
 * 其中有一个帐户（所有者）可以被授予对特定函数的独占访问权。
 *
 * 这个 {Ownable} 合约的扩展包括一个两步所有权转移机制，
 * // 新所有者必须调用 {acceptOwnership} 才能替换旧所有者。
 * // 这有助于防止常见错误，例如将所有权转移到不正确的帐户，或转移到无法与权限系统交互的合约。
 *
 * 初始所有者在部署时在 `Ownable` 的构造函数中指定。之后可以通过 {transferOwnership} 和 {acceptOwnership} 更改。
 * 此模块通过继承使用。它将提供父合约（Ownable）的所有功能。
 */
abstract contract Ownable2Step is Ownable {
    // 待定所有者的地址
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev 返回待定所有者的地址。
     */
    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    /**
     * @dev 开始将合约的所有权转移给一个新帐户。如果存在待定转移，则替换它。
     * 只能由当前所有者调用。
     * 允许将 `newOwner` 设置为零地址；这可用于取消已发起的所有权转移。
     */
    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    /**
     * @dev 将合约的所有权转移给一个新帐户 (`newOwner`) 并删除任何待定所有者。
     * 无访问限制的内部函数。
     */
    function _transferOwnership(address newOwner) internal virtual override {
        delete _pendingOwner;
        super._transferOwnership(newOwner);
    }

    /**
     * @dev 新所有者接受所有权转移。
     */
    function acceptOwnership() public virtual {
        address sender = _msgSender();
        if (pendingOwner() != sender) {
            revert OwnableUnauthorizedAccount(sender);
        }
        _transferOwnership(sender);
    }
}
