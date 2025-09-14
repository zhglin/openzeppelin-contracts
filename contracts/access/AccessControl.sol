// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (access/AccessControl.sol)

pragma solidity ^0.8.20;

import {IAccessControl} from "./IAccessControl.sol";
import {Context} from "../utils/Context.sol";
import {IERC165, ERC165} from "../utils/introspection/ERC165.sol";

/**
 * @dev 合约模块，允许子合约实现基于角色的访问控制机制。
 * 这是一个轻量级版本，不允许枚举角色成员，除非通过访问合约事件日志的链下方式。
 * 某些应用可能受益于链上可枚举性，对于这些情况，请参见 {AccessControlEnumerable}。
 *
 * 角色通过其 `bytes32` 标识符引用。这些标识符应在外部API中公开且唯一。
 * 实现这一点的最佳方法是使用 `public constant` 哈希摘要：
 *
 * ```solidity
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * 角色可用于表示一组权限。要限制对函数调用的访问，请使用 {hasRole}：
 *
 * ```solidity
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * 角色可以通过 {grantRole} 和 {revokeRole} 函数动态授予和撤销。
 * 每个角色都有一个关联的管理员角色，只有拥有角色管理员角色的帐户才能调用 {grantRole} 和 {revokeRole}。
 *
 * 默认情况下，所有角色的管理员角色都是 `DEFAULT_ADMIN_ROLE`，这意味着只有拥有此角色的帐户才能授予或撤销其他角色。
 * 可以使用 {_setRoleAdmin} 创建更复杂的角色关系。
 *
 * 警告：`DEFAULT_ADMIN_ROLE` 也是其自身的管理员：它有权授予和撤销此角色。
 * 应采取额外的预防措施来保护已被授予该角色的帐户。
 * 我们建议使用 {AccessControlDefaultAdminRules} 来为此角色强制执行额外的安全措施。
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    // 每个角色的数据结构
    struct RoleData {
        mapping(address account => bool) hasRole; // 角色成员映射
        bytes32 adminRole;  // 该角色的管理员角色, 这里也是角色
    }

    // 角色标识符到其数据的映射
    mapping(bytes32 role => RoleData) private _roles; 

    /**  
    * 默认管理员角色的标识符
    * 对于 adminRole 这个 bytes32 类型的成员，它的默认值是 0x00。
    * 所以，任何新创建的角色，其管理员角色（adminRole）默认就是 `DEFAULT_ADMIN_ROLE`。你不需要手动去设置它，这是 Solidity 底层机制保证的。
    * 
    * DEFAULT_ADMIN_ROLE 最直接、最明确的“被使用”的场景，通常是在合约的 constructor (构造函数) 中。
    * 合约部署者需要将 DEFAULT_ADMIN_ROLE授予一个初始的管理员账户（通常是部署者自己）。
    */
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev 检查帐户是否具有特定角色的修饰器。
     * 如果没有，则以 {AccessControlUnauthorizedAccount} 错误回滚，并包含所需角色。
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev 如果 `account` 已被授予 `role`，则返回 `true`。
     */
    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        return _roles[role].hasRole[account];
    }

    /**
     * @dev 如果 `_msgSender()` 缺少 `role`，则以 {AccessControlUnauthorizedAccount} 错误回滚。
     * 重写此函数会更改 {onlyRole} 修饰器的行为。
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev 如果 `account` 缺少 `role`，则以 {AccessControlUnauthorizedAccount} 错误回滚。
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert AccessControlUnauthorizedAccount(account, role);
        }
    }

    /**
     * @dev 返回控制 `role` 的管理员角色。参见 {grantRole} 和 {revokeRole}。
     * 要更改角色的管理员，请使用 {_setRoleAdmin}。
     */
    function getRoleAdmin(bytes32 role) public view virtual returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev 将 `role` 授予 `account`。
     * 如果 `account` 尚未被授予 `role`，则触发 {RoleGranted} 事件。
     * 要求：
     * - 调用者必须拥有 `role` 的管理员角色。
     * 可能触发 {RoleGranted} 事件。
     */
    function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev 从 `account` 撤销 `role`。
     * 如果 `account` 已被授予 `role`，则触发 {RoleRevoked} 事件。
     * 要求：
     * - 调用者必须拥有 `role` 的管理员角色。
     * 可能触发 {RoleRevoked} 事件。
     */
    function revokeRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev 从调用帐户中撤销 `role`。
     * 角色通常通过 {grantRole} 和 {revokeRole} 进行管理：
     * 此函数的目的是为帐户提供一种在被盗用（例如当受信任的设备丢失时）时放弃其权限的机制。
     * 如果调用帐户的 `role` 已被撤销，则触发 {RoleRevoked} 事件。
     * 要求：
     * - 调用者必须是 `callerConfirmation`。
     * 可能触发 {RoleRevoked} 事件。
     */
    function renounceRole(bytes32 role, address callerConfirmation) public virtual {
        // 只能由账户本身调用
        if (callerConfirmation != _msgSender()) {
            revert AccessControlBadConfirmation();
        }

        _revokeRole(role, callerConfirmation);
    }

    /**
     * @dev 将 `adminRole` 设置为 `role` 的管理员角色。
     * 触发 {RoleAdminChanged} 事件。
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev 尝试将 `role` 授予 `account`，并返回一个布尔值，指示是否已授予 `role`。
     * 无访问限制的内部函数。
     * 可能触发 {RoleGranted} 事件。
     */
    function _grantRole(bytes32 role, address account) internal virtual returns (bool) {
        if (!hasRole(role, account)) {
            _roles[role].hasRole[account] = true;
            emit RoleGranted(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev 尝试从 `account` 撤销 `role`，并返回一个布尔值，指示是否已撤销 `role`。
     * 无访问限制的内部函数。
     * 可能触发 {RoleRevoked} 事件。
     */
    function _revokeRole(bytes32 role, address account) internal virtual returns (bool) {
        if (hasRole(role, account)) {
            _roles[role].hasRole[account] = false;
            emit RoleRevoked(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }
}
