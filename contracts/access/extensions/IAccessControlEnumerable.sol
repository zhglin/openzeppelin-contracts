// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (access/extensions/IAccessControlEnumerable.sol)

pragma solidity >=0.8.4;

import {IAccessControl} from "../IAccessControl.sol";

/**
 * @dev 为支持ERC-165检测而声明的AccessControlEnumerable的外部接口。
 */
interface IAccessControlEnumerable is IAccessControl {
    /**
     * @dev 返回拥有 `role` 的帐户之一。`index` 必须是介于 0 和 {getRoleMemberCount} 之间的值（不包括 {getRoleMemberCount}）。
     * 角色持有者不按任何特定方式排序，其顺序可能随时更改。
     *
     * 警告：当使用 {getRoleMember} 和 {getRoleMemberCount} 时，请确保在同一个区块上执行所有查询。
     * 在你获取角色成员总数（`getRoleMemberCount`）和你逐个获取角色成员（`getRoleMember`）的这两个操作之间，
     *  区块链的状态可能已经发生了改变。
     * 
     * 有关更多信息，请参阅以下
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[论坛帖子]。
     */
    function getRoleMember(bytes32 role, uint256 index) external view returns (address);

    /**
     * @dev 返回拥有 `role` 的帐户数。可与 {getRoleMember} 一起使用以枚举角色的所有持有者。
     */
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
}
