// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (最后更新于 v5.4.0) (access/manager/IAuthority.sol)

pragma solidity >=0.4.16;

/**
 * @dev 最初在 Dappsys 中定义的标准权限接口。
 */
interface IAuthority {
    /**
     * @dev 如果调用者可以在目标上调用由函数选择器标识的函数，则返回 true。
     */
    function canCall(address caller, address target, bytes4 selector) external view returns (bool allowed);
}
