// SPDX-License-Identifier: MIT
// OpenZeppelin 合约（最后更新于 v5.4.0）(access/manager/IAccessManaged.sol)

pragma solidity >=0.8.4;

interface IAccessManaged {
    /**
     * @dev 管理此合约的权限地址已更新。
     */
    event AuthorityUpdated(address authority);

    error AccessManagedUnauthorized(address caller);
    error AccessManagedRequiredDelay(address caller, uint32 delay);
    error AccessManagedInvalidAuthority(address authority);

    /**
     * @dev 返回当前的权限地址。
     */
    function authority() external view returns (address);

    /**
     * @dev 将控制权转移给新的权限地址。调用者必须是当前的权限地址。
     */
    function setAuthority(address) external;

    /**
     * @dev 仅在延迟受限调用的上下文中，在计划操作被执行的那一刻返回 true。
     * 在合约执行攻击者控制的调用的情况下，防止延迟受限调用的拒绝服务攻击。
     */
    function isConsumingScheduledOp() external view returns (bytes4);
}
