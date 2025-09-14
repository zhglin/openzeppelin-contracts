// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (access/IAccessControl.sol)

pragma solidity >=0.8.4;

/**
 * @dev 为支持ERC-165检测而声明的AccessControl的外部接口。
 */
interface IAccessControl {
    /**
     * @dev `account` 缺少某个角色。
     */
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    /**
     * @dev 函数的调用者不是预期的调用者。
     * 注意：不要与 {AccessControlUnauthorizedAccount} 混淆。
     */
    error AccessControlBadConfirmation();

    /**
     * @dev 当 `newAdminRole` 被设置为 `role` 的管理员角色，替换 `previousAdminRole` 时触发。
     * `DEFAULT_ADMIN_ROLE` 是所有角色的初始管理员，尽管没有触发 {RoleAdminChanged} 事件来表明这一点。
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev 当 `account` 被授予 `role` 时触发。
     * `sender` 是发起合约调用的帐户。该帐户拥有（被授予角色的）管理员角色。
     * 预期在通过内部 {AccessControl-_grantRole} 授予角色时使用。
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev 当 `account` 的 `role` 被撤销时触发。
     * `sender` 是发起合约调用的帐户：
     *   - 如果使用 `revokeRole`，它是管理员角色的承担者
     *   - 如果使用 `renounceRole`，它是角色承担者（即 `account`）
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev 如果 `account` 已被授予 `role`，则返回 `true`。
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev 返回控制 `role` 的管理员角色。参见 {grantRole} 和 {revokeRole}。
     * 要更改角色的管理员，请使用 {AccessControl-_setRoleAdmin}。
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev 将 `role` 授予 `account`。
     * 如果 `account` 尚未被授予 `role`，则触发 {RoleGranted} 事件。
     * 要求：
     * - 调用者必须拥有 `role` 的管理员角色。
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev 从 `account` 撤销 `role`。
     * 如果 `account` 已被授予 `role`，则触发 {RoleRevoked} 事件。
     * 要求：
     * - 调用者必须拥有 `role` 的管理员角色。
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev 从调用帐户中撤销 `role`。
     * 角色通常通过 {grantRole} 和 {revokeRole} 进行管理：
     * 此函数的目的是为帐户提供一种在被盗用（例如当受信任的设备丢失时）时放弃其权限的机制。
     * 如果调用帐户已被授予 `role`，则触发 {RoleRevoked} 事件。
     * 要求：
     * - 调用者必须是 `callerConfirmation`。
     */
    function renounceRole(bytes32 role, address callerConfirmation) external;
}
