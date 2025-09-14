// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (access/extensions/AccessControlDefaultAdminRules.sol)

pragma solidity ^0.8.20;

import {IAccessControlDefaultAdminRules} from "./IAccessControlDefaultAdminRules.sol";
import {AccessControl, IAccessControl} from "../AccessControl.sol";
import {SafeCast} from "../../utils/math/SafeCast.sol";
import {Math} from "../../utils/math/Math.sol";
import {IERC5313} from "../../interfaces/IERC5313.sol";
import {IERC165} from "../../utils/introspection/ERC165.sol";

/**
 * @dev {AccessControl} 的扩展，允许指定特殊规则来管理 `DEFAULT_ADMIN_ROLE` 的持有者，
 * 这是一个敏感角色，对系统中可能拥有特权的其他角色具有特殊权限。
 *
 * 如果特定角色没有分配管理员角色，`DEFAULT_ADMIN_ROLE` 的持有者将有能力授予和撤销该角色。
 *
 * 此合约在 {AccessControl} 的基础上实现了以下风险缓解措施：
 *
 * * 从部署开始，只有一个帐户持有 `DEFAULT_ADMIN_ROLE`，直到它可能被放弃。
 * * 强制执行一个两步过程来将 `DEFAULT_ADMIN_ROLE` 转移给另一个帐户。
 * * 在两个步骤之间强制执行一个可配置的延迟，并有能力在转移被接受之前取消。
 * 
 * * 延迟可以通过计划进行更改，请参见 {changeDefaultAdminDelay}。
 * * 角色转移在计划后必须至少等待一个区块才能被接受。
 * * 不可能使用另一个角色来管理 `DEFAULT_ADMIN_ROLE`。
 *
 * 示例用法：
 *
 * ```solidity
 * contract MyToken is AccessControlDefaultAdminRules {
 *   constructor() AccessControlDefaultAdminRules(
 *     3 days,
 *     msg.sender // 明确的初始 `DEFAULT_ADMIN_ROLE` 持有者
 *    ) {}
 * }
 * ```
 */
abstract contract AccessControlDefaultAdminRules is IAccessControlDefaultAdminRules, IERC5313, AccessControl {
    // 待定管理员对，频繁一起读/写
    // `_pendingDefaultAdmin` (address): 存储被提议为新任默认管理员的账户地址。
    // `_pendingDefaultAdminSchedule` (uint48): 存储一个未来的时间戳，只有在这个时间戳之后，被提议的新管理员才能接受并完成转移。
    // 能否转移要看_pendingDefaultAdminSchedule的时间,_pendingDefaultAdminSchedule依赖_pendingDelay
    address private _pendingDefaultAdmin;
    uint48 private _pendingDefaultAdminSchedule; // 0 == 未设置

    // 当前默认管理员对，频繁一起读/写
    // _currentDelay 代表了在任何给定时间点，转移 DEFAULT_ADMIN_ROLE 所必须等待的确切时间。
    // _currentDefaultAdmin记录当前的管理员地址。
    uint48 private _currentDelay;
    address private _currentDefaultAdmin;

    // 待定延迟对，频繁一起读/写
    // 当现有的 DEFAULT_ADMIN_ROLE 持有者想要更改执行操作（如转移管理员权限）所需的延迟时间时，他们会调用 changeDefaultAdminDelay(newDelay)函数。
    // 这个新的延迟时间 newDelay 不会立即生效，而是被存储在 _pendingDelay 中。
    uint48 private _pendingDelay;
    // 这个时间戳代表了 _pendingDelay 中存储的新延迟时间可以正式生效的最早时间点。
    // 当 changeDefaultAdminDelay 被调用时，合约会根据当前延迟和新延迟的差异计算出一个等待期，然后将 block.timestamp + 等待期 的结果存入_pendingDelaySchedule。
    // _pendingDelaySchedule这个值并不一定等于当前时间戳+_pendingDelay的值 
    uint48 private _pendingDelaySchedule; // 0 == 未设置 无法获取发起变更时的那个 `block.timestamp`,所以需要记录这个值
    // 通过_pendingDelaySchedule的时间控制_pendingDelay是否生效

    /**
     * @dev 设置 {defaultAdminDelay} 和 {defaultAdmin} 地址的初始值。
     */
    constructor(uint48 initialDelay, address initialDefaultAdmin) {
        if (initialDefaultAdmin == address(0)) {
            revert AccessControlInvalidDefaultAdmin(address(0));
        }
        _currentDelay = initialDelay;
        // initialDefaultAdmin设置为DEFAULT_ADMIN_ROLE角色成员
        _grantRole(DEFAULT_ADMIN_ROLE, initialDefaultAdmin);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlDefaultAdminRules).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC5313
    function owner() public view virtual returns (address) {
        return defaultAdmin();
    }

    ///
    /// 重写 AccessControl 角色管理
    ///

    /**
     * @dev 参见 {AccessControl-grantRole}。对于 `DEFAULT_ADMIN_ROLE` 会回滚。
     */
    function grantRole(bytes32 role, address account) public virtual override(AccessControl, IAccessControl) {
        // 不允许给予DEFAULT_ADMIN_ROLE的角色
        if (role == DEFAULT_ADMIN_ROLE) {
            revert AccessControlEnforcedDefaultAdminRules();
        }
        super.grantRole(role, account);
    }

    /**
     * @dev 参见 {AccessControl-revokeRole}。对于 `DEFAULT_ADMIN_ROLE` 会回滚。
     */
    function revokeRole(bytes32 role, address account) public virtual override(AccessControl, IAccessControl) {
        // 不允许撤销DEFAULT_ADMIN_ROLE的角色
        if (role == DEFAULT_ADMIN_ROLE) {
            revert AccessControlEnforcedDefaultAdminRules();
        }
        // 调用父类的revokeRole方法,父类的revokeRole方法调用_revokeRole函数,
        // AccessControlDefaultAdminRules对_revokeRole函数进行了重写，
        // 所以这里的调用会优先执行AccessControlDefaultAdminRules中的_revokeRole。
        super.revokeRole(role, account);
    }

    /**
     * @dev 参见 {AccessControl-renounceRole}。
     *
     * 对于 `DEFAULT_ADMIN_ROLE`，它只允许通过首先调用 {beginDefaultAdminTransfer} 到 `address(0)` 来分两步放弃，
     * 因此在调用此函数时，要求 {pendingDefaultAdmin} 的计划也已通过。
     *
     * 执行后，将无法调用 `onlyRole(DEFAULT_ADMIN_ROLE)` 函数。
     *
     * 注意：放弃 `DEFAULT_ADMIN_ROLE` 将使合约没有 {defaultAdmin}，
     * 从而禁用任何仅对其可用的功能，以及重新分配非管理角色的可能性。
     */
    function renounceRole(bytes32 role, address account) public virtual override(AccessControl, IAccessControl) {
        // 当前的最高管理员（`defaultAdmin()`）正在试图放弃他自己的最高管理员角色（`DEFAULT_ADMIN_ROLE`）
        if (role == DEFAULT_ADMIN_ROLE && account == defaultAdmin()) {
            (address newDefaultAdmin, uint48 schedule) = pendingDefaultAdmin();
            // 
            if (newDefaultAdmin != address(0) || !_isScheduleSet(schedule) || !_hasSchedulePassed(schedule)) {
                revert AccessControlEnforcedDefaultAdminDelay(schedule);
            }
            delete _pendingDefaultAdminSchedule;
        }
        super.renounceRole(role, account);
    }

    /**
     * @dev 参见 {AccessControl-_grantRole}。
     *
     * 对于 `DEFAULT_ADMIN_ROLE`，仅当尚无 {defaultAdmin} 或
     * 该角色先前已被放弃时，才允许授予。
     *
     * 注意：通过另一种机制公开此函数可能会使 `DEFAULT_ADMIN_ROLE`
     * 再次可分配。请确保在您的实现中保证这是预期的行为。
     */
    function _grantRole(bytes32 role, address account) internal virtual override returns (bool) {
        if (role == DEFAULT_ADMIN_ROLE) {
            // 只有在没有当前默认管理员的情况下，才能授予DEFAULT_ADMIN_ROLE角色
            if (defaultAdmin() != address(0)) {
                revert AccessControlEnforcedDefaultAdminRules();
            }
            _currentDefaultAdmin = account;
        }
        return super._grantRole(role, account);
    }

    /// @inheritdoc AccessControl
    function _revokeRole(bytes32 role, address account) internal virtual override returns (bool) {
        // 只有当撤销DEFAULT_ADMIN_ROLE角色的持有者是当前的默认管理员时，才删除_currentDefaultAdmin。
        if (role == DEFAULT_ADMIN_ROLE && account == defaultAdmin()) {
            delete _currentDefaultAdmin;
        }
        return super._revokeRole(role, account);
    }

    /**
     * @dev 参见 {AccessControl-_setRoleAdmin}。对于 `DEFAULT_ADMIN_ROLE` 会回滚。
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual override {
        // 不允许更改DEFAULT_ADMIN_ROLE的管理员角色
        if (role == DEFAULT_ADMIN_ROLE) {
            revert AccessControlEnforcedDefaultAdminRules();
        }
        super._setRoleAdmin(role, adminRole);
    }

    ///
    /// AccessControlDefaultAdminRules 访问器
    ///

    /// @inheritdoc IAccessControlDefaultAdminRules
    function defaultAdmin() public view virtual returns (address) {
        return _currentDefaultAdmin;
    }

    /// @inheritdoc IAccessControlDefaultAdminRules
    function pendingDefaultAdmin() public view virtual returns (address newAdmin, uint48 schedule) {
        return (_pendingDefaultAdmin, _pendingDefaultAdminSchedule);
    }

    /// @inheritdoc IAccessControlDefaultAdminRules
    // 这个函数是获取当前应遵守的管理员延迟时间的唯一真实来源。它自动处理了从旧延迟到新延迟的“无缝切换”。
    // 有一个待处理的延迟变更，并且其生效时间已到，函数就会返回 _pendingDelay（新的延迟时间）
    // 否则（即没有待处理的变更，或者变更的生效时间未到），函数就会返回 _currentDelay（当前正在使用的延迟时间）。
    // 获取在当前时间点，任何需要延迟的操作（如 beginDefaultAdminTransfer）应该遵守的延迟时间。
    function defaultAdminDelay() public view virtual returns (uint48) {
        uint48 schedule = _pendingDelaySchedule;
        return (_isScheduleSet(schedule) && _hasSchedulePassed(schedule)) ? _pendingDelay : _currentDelay;
    }

    /// @inheritdoc IAccessControlDefaultAdminRules
    // 查询是否有一个已提议、但尚未生效的延迟变更。这让外部用户可以监控即将发生的变化。
    // 只提供查询功能
    function pendingDefaultAdminDelay() public view virtual returns (uint48 newDelay, uint48 schedule) {
        schedule = _pendingDelaySchedule;
        return (_isScheduleSet(schedule) && !_hasSchedulePassed(schedule)) ? (_pendingDelay, schedule) : (0, 0);
    }

    /// @inheritdoc IAccessControlDefaultAdminRules
    function defaultAdminDelayIncreaseWait() public view virtual returns (uint48) {
        return 5 days;
    }

    ///
    /// AccessControlDefaultAdminRules 公共和内部设置器，用于 defaultAdmin/pendingDefaultAdmin
    ///
    // 设置新的默认管理员转移。
    /// @inheritdoc IAccessControlDefaultAdminRules
    function beginDefaultAdminTransfer(address newAdmin) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _beginDefaultAdminTransfer(newAdmin);
    }

    /**
     * @dev 参见 {beginDefaultAdminTransfer}。
     *
     * 无访问限制的内部函数。
     */
    function _beginDefaultAdminTransfer(address newAdmin) internal virtual {
        uint48 newSchedule = SafeCast.toUint48(block.timestamp) + defaultAdminDelay();
        _setPendingDefaultAdmin(newAdmin, newSchedule);
        emit DefaultAdminTransferScheduled(newAdmin, newSchedule);
    }

    /// @inheritdoc IAccessControlDefaultAdminRules
    // 取消待定的默认管理员转移。
    // 调用者必须是当前的默认管理员。
    function cancelDefaultAdminTransfer() public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _cancelDefaultAdminTransfer();
    }

    /**
     * @dev 参见 {cancelDefaultAdminTransfer}。
     *
     * 无访问限制的内部函数。
     */
    function _cancelDefaultAdminTransfer() internal virtual {
        _setPendingDefaultAdmin(address(0), 0);
    }

    /// @inheritdoc IAccessControlDefaultAdminRules
    // 调用者必须是待定的默认管理员，并且接受计划的时间戳必须已经过去。
    // 该函数完成后，调用者将获得 DEFAULT_ADMIN_ROLE，而前任管理员将失去该角色。
    // 此外，待定的默认管理员和其计划将被重置为零值。
    function acceptDefaultAdminTransfer() public virtual {
        (address newDefaultAdmin, ) = pendingDefaultAdmin();
        if (_msgSender() != newDefaultAdmin) {
            // 强制 newDefaultAdmin 显式接受。
            revert AccessControlInvalidDefaultAdmin(_msgSender());
        }
        _acceptDefaultAdminTransfer();
    }

    /**
     * @dev 参见 {acceptDefaultAdminTransfer}。
     *
     * 无访问限制的内部函数。
     */
    function _acceptDefaultAdminTransfer() internal virtual {
        (address newAdmin, uint48 schedule) = pendingDefaultAdmin();
        if (!_isScheduleSet(schedule) || !_hasSchedulePassed(schedule)) {
            revert AccessControlEnforcedDefaultAdminDelay(schedule);
        }
        _revokeRole(DEFAULT_ADMIN_ROLE, defaultAdmin());
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        delete _pendingDefaultAdmin;
        delete _pendingDefaultAdminSchedule;
    }

    ///
    /// AccessControlDefaultAdminRules 公共和内部设置器，用于 defaultAdminDelay/pendingDefaultAdminDelay
    ///

    /// @inheritdoc IAccessControlDefaultAdminRules
    // 设置delay的新值。_pendingDelaySchedule值记录新delay何时可以生效。
    function changeDefaultAdminDelay(uint48 newDelay) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _changeDefaultAdminDelay(newDelay);
    }

    /**
     * @dev 参见 {changeDefaultAdminDelay}。
     *
     * 无访问限制的内部函数。
     */
    function _changeDefaultAdminDelay(uint48 newDelay) internal virtual {
        uint48 newSchedule = SafeCast.toUint48(block.timestamp) + _delayChangeWait(newDelay);
        _setPendingDelay(newDelay, newSchedule);
        emit DefaultAdminDelayChangeScheduled(newDelay, newSchedule);
    }

    /// @inheritdoc IAccessControlDefaultAdminRules
    function rollbackDefaultAdminDelay() public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _rollbackDefaultAdminDelay();
    }

    /**
     * @dev 参见 {rollbackDefaultAdminDelay}。
     *
     * 无访问限制的内部函数。
     */
    function _rollbackDefaultAdminDelay() internal virtual {
        _setPendingDelay(0, 0);
    }

    /**
     * @dev 返回 `newDelay` 成为新的 {defaultAdminDelay} 之后需要等待的秒数。
     *
     * 返回的值保证，如果延迟减少，它将在等待 honoring 先前设置的延迟之后生效。
     *
     * 参见 {defaultAdminDelayIncreaseWait}。
     */
    function _delayChangeWait(uint48 newDelay) internal view virtual returns (uint48) {
        uint48 currentDelay = defaultAdminDelay();

        // 增加延迟时，我们计划延迟更改在“新延迟”周期过后发生，
        // 最长不超过 defaultAdminDelayIncreaseWait 给定的最大值，默认为 5 天。例如，如果从 1 天增加到 3 天，
        // 新的延迟将在 3 天后生效。如果从 1 天增加到 10 天，新的延迟将在 5 天后生效。
        // 5 天的等待期旨在能够修复诸如使用毫秒代替秒之类的错误。
        //
        // 减少延迟时，我们等待“当前延迟”和“新延迟”之间的差值。这保证了
        // 在计划延迟更改时，管理员转移不能比“当前延迟”更快。
        // 例如，如果从 10 天减少到 3 天，新的延迟将在 7 天后生效。
        return
            newDelay > currentDelay
                ? uint48(Math.min(newDelay, defaultAdminDelayIncreaseWait())) // 无需 safecast，两个输入都是 uint48
                : currentDelay - newDelay;
    }

    ///
    /// 私有设置器
    ///

    /**
     * @dev 待定管理员及其计划的元组的设置器。
     *
     * 可能触发 DefaultAdminTransferCanceled 事件。
     */
    function _setPendingDefaultAdmin(address newAdmin, uint48 newSchedule) private {
        (, uint48 oldSchedule) = pendingDefaultAdmin();

        _pendingDefaultAdmin = newAdmin;
        _pendingDefaultAdminSchedule = newSchedule;

        // 只有在尚未接受的情况下，才会设置来自 `pendingDefaultAdmin()` 的 `oldSchedule`。
        if (_isScheduleSet(oldSchedule)) {
            // 当计划了另一个默认管理员时，为隐式取消触发事件。
            emit DefaultAdminTransferCanceled();
        }
    }

    /**
     * @dev 待定延迟及其计划的元组的设置器。
     *
     * 可能触发 DefaultAdminDelayChangeCanceled 事件。
     */
    function _setPendingDelay(uint48 newDelay, uint48 newSchedule) private {
        uint48 oldSchedule = _pendingDelaySchedule;

        if (_isScheduleSet(oldSchedule)) {
            if (_hasSchedulePassed(oldSchedule)) {
                // 实现虚拟延迟
                _currentDelay = _pendingDelay;
            } else {
                // 当计划了另一个延迟时，为隐式取消触发事件。
                emit DefaultAdminDelayChangeCanceled();
            }
        }

        _pendingDelay = newDelay;
        _pendingDelaySchedule = newSchedule;
    }

    ///
    /// 私有帮助函数
    ///

    /**
     * @dev 定义一个 `schedule` 是否被视为已设置。为了保持一致性。
     */
    function _isScheduleSet(uint48 schedule) private pure returns (bool) {
        return schedule != 0;
    }

    /**
     * @dev 定义一个 `schedule` 是否被视为已通过。为了保持一致性。
     */
    function _hasSchedulePassed(uint48 schedule) private view returns (bool) {
        return schedule < block.timestamp;
    }
}
