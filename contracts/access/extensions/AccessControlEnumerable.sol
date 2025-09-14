// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (access/extensions/AccessControlEnumerable.sol)

pragma solidity ^0.8.20;

import {IAccessControlEnumerable} from "./IAccessControlEnumerable.sol";
import {AccessControl} from "../AccessControl.sol";
import {EnumerableSet} from "../../utils/structs/EnumerableSet.sol";
import {IERC165} from "../../utils/introspection/ERC165.sol";

/**
 * @dev {AccessControl} 的扩展，允许枚举每个角色的成员。
 */
abstract contract AccessControlEnumerable is IAccessControlEnumerable, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    // 角色标识符到其成员集合的映射
    mapping(bytes32 role => EnumerableSet.AddressSet) private _roleMembers;

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlEnumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev 返回拥有 `role` 的帐户之一。`index` 必须是介于 0 和 {getRoleMemberCount} 之间的值（不包括 {getRoleMemberCount}）。
     * 角色持有者不按任何特定方式排序，其顺序可能随时更改。
     * 警告：当使用 {getRoleMember} 和 {getRoleMemberCount} 时，请确保在同一个区块上执行所有查询。
     * 有关更多信息，请参阅以下
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[论坛帖子]。
     */
    function getRoleMember(bytes32 role, uint256 index) public view virtual returns (address) {
        return _roleMembers[role].at(index);
    }

    /**
     * @dev 返回拥有 `role` 的帐户数。可与 {getRoleMember} 一起使用以枚举角色的所有持有者。
     */
    function getRoleMemberCount(bytes32 role) public view virtual returns (uint256) {
        return _roleMembers[role].length();
    }

    /**
     * @dev 返回所有拥有 `role` 的帐户
     */
    function getRoleMembers(bytes32 role) public view virtual returns (address[] memory) {
        return _roleMembers[role].values();
    }

    /**
     * @dev 重载 {AccessControl-_grantRole} 以跟踪可枚举的成员关系
     */
    function _grantRole(bytes32 role, address account) internal virtual override returns (bool) {
        bool granted = super._grantRole(role, account);
        // 添加
        if (granted) {
            _roleMembers[role].add(account);
        }
        return granted;
    }

    /**
     * @dev 重载 {AccessControl-_revokeRole} 以跟踪可枚举的成员关系
     */
    function _revokeRole(bytes32 role, address account) internal virtual override returns (bool) {
        bool revoked = super._revokeRole(role, account);
        // 删除
        if (revoked) {
            _roleMembers[role].remove(account);
        }
        return revoked;
    }
}
