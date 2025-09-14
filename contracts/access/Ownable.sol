// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;

import {Context} from "../utils/Context.sol";

/**
 * @dev 合约模块，提供基本的访问控制机制，其中有一个帐户（所有者）可以被授予对特定函数的独占访问权。
 * 初始所有者被设置为部署者提供的地址。之后可以通过 {transferOwnership} 更改。
 * 此模块通过继承使用。它将提供 `onlyOwner` 修饰器，可以应用于您的函数，以将其使用限制为所有者。
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev 调用者帐户无权执行操作。
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev 所有者不是有效的帐户。（例如 `address(0)`）
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev 初始化合约，将部署者提供的地址设置为初始所有者。
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev 如果被除所有者以外的任何帐户调用，则抛出异常。
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev 返回当前所有者的地址。
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev 如果发送者不是所有者，则抛出异常。
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev 使合约没有所有者。将无法调用 `onlyOwner` 函数。只能由当前所有者调用。
     * 注意：放弃所有权将使合约没有所有者，从而禁用任何仅对所有者可用的功能。
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev 将合约的所有权转移给一个新帐户 (`newOwner`)。
     * 只能由当前所有者调用。
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev 将合约的所有权转移给一个新帐户 (`newOwner`)。
     * 无访问限制的内部函数。
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
