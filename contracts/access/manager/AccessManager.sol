// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (最后更新于 v5.1.0) (access/manager/AccessManager.sol)

pragma solidity ^0.8.20;

import {IAccessManager} from "./IAccessManager.sol";
import {IAccessManaged} from "./IAccessManaged.sol";
import {Address} from "../../utils/Address.sol";
import {Context} from "../../utils/Context.sol";
import {Multicall} from "../../utils/Multicall.sol";
import {Math} from "../../utils/math/Math.sol";
import {Time} from "../../utils/types/Time.sol";
import {Hashes} from "../../utils/cryptography/Hashes.sol";

/**
 * @dev AccessManager 是一个用于存储系统权限的中心化合约。
 * 它将“什么人能做”（权限）和“做什么事”（业务）完全分离开来。
 * 
 * 在 AccessManager 实例控制下的智能合约被称为目标（target），它将继承自 {AccessManaged} 合约，
 * 连接到此合约作为其管理器，并在选定的一组需授权的函数上实现 {AccessManaged-restricted} 修改器。
 * 请注意，任何没有此设置的函数都不会被有效限制。
 *
 * 此类函数的限制规则以“角色”的形式定义，角色由一个 `uint64` 标识，并按目标（`address`）和函数选择器（`bytes4`）进行范围限定。
 * 这些角色存储在此合约中，并可由管理员（`ADMIN_ROLE` 成员）在延迟后进行配置（参见 {getTargetAdminDelay}）。
 *
 * 对于每个目标合约，管理员可以无延迟地配置以下内容：
 *
 * * 通过 {updateAuthority} 配置目标的 {AccessManaged-authority}。
 * * 通过 {setTargetClosed} 关闭或开放一个目标，同时保持权限不变。
 * * 通过 {setTargetFunctionRole} 配置允许（或不允许）调用给定函数（由其选择器标识）的角色。
 *
 * 默认情况下，每个地址都是 `PUBLIC_ROLE` 的成员，并且每个目标函数都被限制为 `ADMIN_ROLE`，直到另行配置。
 * 此外，每个角色都有以下配置选项，仅限于此管理器的管理员操作：
 *
 * * 通过 {setRoleAdmin} 设置一个角色的管理员角色，该管理员可以授予或撤销角色。
 * * 通过 {setRoleGuardian} 设置一个角色的守护者角色，该守护者被允许取消操作。
 * * 通过 {setGrantDelay} 设置一个角色在被授予后生效的延迟。
 * * 通过 {setTargetAdminDelay} 设置任何目标管理员操作的延迟。
 * * 通过 {labelRole} 为角色设置标签以提高可发现性。
 *
 * 任何账户都可以通过使用 {grantRole} 和 {revokeRole} 函数被添加或移除出任意数量的角色，
 * 这些函数仅限于每个角色的管理员（参见 {getRoleAdmin}）调用。
 *
 * 由于受管理系统的所有权限都可以被此实例的管理员修改，因此预计他们将是高度安全的
 * （例如，一个多签钱包或一个配置良好的DAO）。
 *
 * 注意：此合约实现了 {IAuthority} 接口的一种形式，但 {canCall} 有额外的返回数据，因此它不继承 `IAuthority`。
 * 然而，它与 `IAuthority` 接口兼容，因为返回数据的前32字节是该接口所期望的布尔值。
 *
 * 注意：实现其他访问控制机制（例如使用 {Ownable}）的系统可以通过将权限（在 {Ownable} 的情况下是所有权）
 * 直接转移到 {AccessManager} 来与之配对。用户将能够通过 {execute} 函数与这些合约交互，
 * 遵循在 {AccessManager} 中注册的访问规则。请记住，在这种情况下，受限函数看到的 msg.sender 将是 {AccessManager} 本身。
 *
 * 警告：在将 {Ownable} 或 {AccessControl} 合约的权限授予 {AccessManager} 时，请非常注意与
 * {Ownable-renounceOwnership} 或 {AccessControl-renounceRole} 等函数相关的危险。
 */
contract AccessManager is Context, Multicall, IAccessManager {
    using Time for *;

    // 存储目标合约详情的结构体。
    struct TargetConfig {
        // 函数选择器对应的角色Id
        mapping(bytes4 selector => uint64 roleId) allowedRoles;
        // 延迟调用时间
        Time.Delay adminDelay;
        // 是否被关闭,不允许调用
        bool closed;
    }

    // 存储角色/账户对详情的结构体。此结构体可放入一个存储槽中。
    struct Access {
        // 用户获得权限的时间点。
        // 如果为0或在未来，则角色权限不可用。
        uint48 since;
        // 执行延迟。仅适用于 restricted() / execute() 调用。
        Time.Delay delay;
    }

    // 存储角色详情的结构体。
    struct Role {
        // 角色的成员。
        mapping(address user => Access access) members;
        // 可以授予或撤销权限的管理员角色id。
        uint64 admin;
        // 可以取消针对需要此角色的函数的操作的守护者。
        uint64 guardian;
        // 角色被授予后生效的延迟。
        Time.Delay grantDelay;
    }

    // 存储已调度操作详情的结构体。此结构体可放入一个存储槽中。
    struct Schedule {
        // 操作可以被执行的时刻。
        uint48 timepoint;
        // 操作的 nonce，以允许第三方合约识别该操作。
        // 1. 链下应用（如UI界面）可以清晰地展示和区分所有待处理的操作，即使用户调度了多个相同的操作。
        // 2. 当操作被执行或取消时，通过事件中的 nonce，可以精确地知道是哪一个“待办事项”被处理了，避免了歧义。
        uint32 nonce;
    }

    /**
     * @dev 管理员角色的标识符。执行大多数配置操作（包括其他角色的管理和目标限制）所必需。
     */
    uint64 public constant ADMIN_ROLE = type(uint64).min; // 0

    /**
     * @dev 公共角色的标识符。自动无延迟地授予所有地址。
     */
    uint64 public constant PUBLIC_ROLE = type(uint64).max; // 2**64-1

    // 目标合约的角色配置
    // mode是占位符名称, 指的是在 mapping 声明中赋予类型的一个临时的、用于描述目的的名字。
    mapping(address target => TargetConfig mode) private _targets;
    // 角色详情
    mapping(uint64 roleId => Role) private _roles;
    // 已调度的操作详情
    mapping(bytes32 operationId => Schedule) private _schedules;

    // 用于识别当前通过 {execute} 执行的操作。
    // 当EVM支持时，这应该是瞬时存储。
    bytes32 private _executionId;

    /**
     * @dev 检查调用者是否被授权执行操作。
     * 有关授权逻辑的详细分解，请参见 {AccessManager} 的描述。
     * _checkAuthorized 的作用就是将 AccessManager 自身的管理功能，也纳入到它自己设计的这套复杂的权限和延迟体系中。
     * 意思是自己也要使用自己开发的产品或遵守自己制定的规则。
     */
    modifier onlyAuthorized() {
        _checkAuthorized();
        _;
    }

    constructor(address initialAdmin) {
        if (initialAdmin == address(0)) {
            revert AccessManagerInvalidInitialAdmin(address(0));
        }

        // 管理员立即生效，没有任何执行延迟。
        _grantRole(ADMIN_ROLE, initialAdmin, 0, 0);
    }

    // =================================================== GETTERS（获取器） ====================================================
    /// @inheritdoc IAccessManager
    // 作为“权限中心”的主要入口。当一个受管理的合约（AccessManaged）上的 restricted 函数被调用时，
    // 它就会来询问 canCall：“嘿，这个调用方能执行这个操作吗？”
    // canCall 不需要返回 true 来表示“非受限”，因为对于真正非受限的调用，流程根本走不到 canCall 这一步。
    // 一个函数是否受限，是在目标合约层面由 `restricted` 修饰器决定的，而不是在 `AccessManager` 层面由 `canCall` 判断的。
    function canCall(
        address caller,
        address target,
        bytes4 selector
    ) public view virtual returns (bool immediate, uint32 delay) {
        if (isTargetClosed(target)) {
            return (false, 0);
        } else if (caller == address(this)) {
            // 这是为 `execute` 流程特设的安检通道。 当一个用户通过 schedule -> wait -> execute 流程执行一个延迟操作时，
            // 最终是由 AccessManager 合约自己去调用目标合约的函数。
            // 调用者是 AccessManager，这意味着调用是通过 {execute} 发送的，并且已经检查了权限。
            // 我们验证在 {execute} 期间设置的调用“标识符”是否正确。
            return (_isExecuting(target, selector), 0);
        } else {
            // 标准的外部调用权限检查
            uint64 roleId = getTargetFunctionRole(target, selector);
            (bool isMember, uint32 currentDelay) = hasRole(roleId, caller);
            return isMember ? (currentDelay == 0, currentDelay) : (false, 0);
        }
    }

    /// @inheritdoc IAccessManager
    // schedule调用的过期时间
    function expiration() public view virtual returns (uint32) {
        return 1 weeks;
    }

    /// @inheritdoc IAccessManager
    function minSetback() public view virtual returns (uint32) {
        return 5 days;
    }

    /// @inheritdoc IAccessManager
    // 目标合约是否被关闭,不允许被调用
    function isTargetClosed(address target) public view virtual returns (bool) {
        return _targets[target].closed;
    }

    /// @inheritdoc IAccessManager
    // 获取目标合约上特定函数选择器的角色Id
    function getTargetFunctionRole(address target, bytes4 selector) public view virtual returns (uint64) {
        return _targets[target].allowedRoles[selector];
    }

    /// @inheritdoc IAccessManager
    // 获取目标合约的延迟生效时间
    function getTargetAdminDelay(address target) public view virtual returns (uint32) {
        return _targets[target].adminDelay.get();
    }

    /// @inheritdoc IAccessManager
    // 获取角色的管理员角色Id
    function getRoleAdmin(uint64 roleId) public view virtual returns (uint64) {
        return _roles[roleId].admin;
    }

    /// @inheritdoc IAccessManager
    function getRoleGuardian(uint64 roleId) public view virtual returns (uint64) {
        return _roles[roleId].guardian;
    }

    /// @inheritdoc IAccessManager
    function getRoleGrantDelay(uint64 roleId) public view virtual returns (uint32) {
        return _roles[roleId].grantDelay.get();
    }

    /// @inheritdoc IAccessManager
    // 获取账户在某个角色上的权限详情,获取时间, 当前延迟, 待定延迟, 生效时间
    function getAccess(
        uint64 roleId,
        address account
    ) public view virtual returns (uint48 since, uint32 currentDelay, uint32 pendingDelay, uint48 effect) {
        Access storage access = _roles[roleId].members[account];

        since = access.since;
        // 当前延迟, 待定延迟, 生效时间
        (currentDelay, pendingDelay, effect) = access.delay.getFull();

        return (since, currentDelay, pendingDelay, effect);
    }

    /// @inheritdoc IAccessManager
    // account是否具有roleId权限,以及执行延迟
    function hasRole(
        uint64 roleId,
        address account
    ) public view virtual returns (bool isMember, uint32 executionDelay) {
        // 所有人都是 PUBLIC_ROLE 的成员，没有延迟。
        if (roleId == PUBLIC_ROLE) {
            return (true, 0);
        } else {
            (uint48 hasRoleSince, uint32 currentDelay, , ) = getAccess(roleId, account);
            return (hasRoleSince != 0 && hasRoleSince <= Time.timestamp(), currentDelay);
        }
    }

    // =============================================== ROLE MANAGEMENT（角色管理） ===============================================
    /// @inheritdoc IAccessManager
    // 只是触发事件,链下工具可以使用它来标记角色。
    function labelRole(uint64 roleId, string calldata label) public virtual onlyAuthorized {
        if (roleId == ADMIN_ROLE || roleId == PUBLIC_ROLE) {
            revert AccessManagerLockedRole(roleId);
        }
        emit RoleLabel(roleId, label);
    }

    /// @inheritdoc IAccessManager
    // 角色分配
    function grantRole(uint64 roleId, address account, uint32 executionDelay) public virtual onlyAuthorized {
        _grantRole(roleId, account, getRoleGrantDelay(roleId), executionDelay);
    }

    /// @inheritdoc IAccessManager
    // 角色撤销
    function revokeRole(uint64 roleId, address account) public virtual onlyAuthorized {
        _revokeRole(roleId, account);
    }

    /// @inheritdoc IAccessManager
    // 角色放弃
    function renounceRole(uint64 roleId, address callerConfirmation) public virtual {
        // 必须是调用者自己放弃
        if (callerConfirmation != _msgSender()) {
            revert AccessManagerBadConfirmation();
        }
        _revokeRole(roleId, callerConfirmation);
    }

    /// @inheritdoc IAccessManager
    // 设置角色的管理员
    function setRoleAdmin(uint64 roleId, uint64 admin) public virtual onlyAuthorized {
        _setRoleAdmin(roleId, admin);
    }

    /// @inheritdoc IAccessManager
    function setRoleGuardian(uint64 roleId, uint64 guardian) public virtual onlyAuthorized {
        _setRoleGuardian(roleId, guardian);
    }

    /// @inheritdoc IAccessManager
    function setGrantDelay(uint64 roleId, uint32 newDelay) public virtual onlyAuthorized {
        _setGrantDelay(roleId, newDelay);
    }

    /**
     * @dev {grantRole} 的内部版本，无访问控制。如果角色是新授予的，则返回 true。
     *
     * 触发一个 {RoleGranted} 事件。
     */
    function _grantRole(
        uint64 roleId,
        address account,
        uint32 grantDelay,
        uint32 executionDelay
    ) internal virtual returns (bool) {
        if (roleId == PUBLIC_ROLE) {
            revert AccessManagerLockedRole(roleId);
        }

        bool newMember = _roles[roleId].members[account].since == 0;
        uint48 since;

        if (newMember) {
            since = Time.timestamp() + grantDelay;
            _roles[roleId].members[account] = Access({since: since, delay: executionDelay.toDelay()});
        } else {
            // 这里没有生效间隔。可以通过 revoke + grant 来重置值，
            // 这有效地允许管理员在角色管理延迟期间对执行延迟进行任何更改。
            (_roles[roleId].members[account].delay, since) = _roles[roleId].members[account].delay.withUpdate(
                executionDelay,
                0
            );
        }

        emit RoleGranted(roleId, account, executionDelay, since, newMember);
        return newMember;
    }

    /**
     * @dev {revokeRole} 的内部版本，无访问控制。此逻辑也用于 {renounceRole}。
     * 如果角色先前已被授予，则返回 true。
     *
     * 如果账户拥有该角色，则触发一个 {RoleRevoked} 事件。
     */
    function _revokeRole(uint64 roleId, address account) internal virtual returns (bool) {
        if (roleId == PUBLIC_ROLE) {
            revert AccessManagerLockedRole(roleId);
        }

        if (_roles[roleId].members[account].since == 0) {
            return false;
        }

        delete _roles[roleId].members[account];

        emit RoleRevoked(roleId, account);
        return true;
    }

    /**
     * @dev {setRoleAdmin} 的内部版本，无访问控制。
     *
     * 触发一个 {RoleAdminChanged} 事件。
     *
     * 注意：允许将管理员角色设置为 `PUBLIC_ROLE`，但这将有效地允许任何人设置授予或撤销此类角色。
     */
    function _setRoleAdmin(uint64 roleId, uint64 admin) internal virtual {
        if (roleId == ADMIN_ROLE || roleId == PUBLIC_ROLE) {
            revert AccessManagerLockedRole(roleId);
        }

        _roles[roleId].admin = admin;

        emit RoleAdminChanged(roleId, admin);
    }

    /**
     * @dev {setRoleGuardian} 的内部版本，无访问控制。
     *
     * 触发一个 {RoleGuardianChanged} 事件。
     *
     * 注意：允许将守护者角色设置为 `PUBLIC_ROLE`，但这将有效地允许任何人取消任何针对此类角色的已调度操作。
     */
    function _setRoleGuardian(uint64 roleId, uint64 guardian) internal virtual {
        if (roleId == ADMIN_ROLE || roleId == PUBLIC_ROLE) {
            revert AccessManagerLockedRole(roleId);
        }

        _roles[roleId].guardian = guardian;

        emit RoleGuardianChanged(roleId, guardian);
    }

    /**
     * @dev {setGrantDelay} 的内部版本，无访问控制。
     *
     * 触发一个 {RoleGrantDelayChanged} 事件。
     */
    function _setGrantDelay(uint64 roleId, uint32 newDelay) internal virtual {
        if (roleId == PUBLIC_ROLE) {
            revert AccessManagerLockedRole(roleId);
        }

        uint48 effect;
        (_roles[roleId].grantDelay, effect) = _roles[roleId].grantDelay.withUpdate(newDelay, minSetback());

        emit RoleGrantDelayChanged(roleId, newDelay, effect);
    }

    // ============================================= FUNCTION MANAGEMENT（函数管理） ==============================================
    /// @inheritdoc IAccessManager
    // 设置目标合约的权限
    // 两个完全不同的函数签名，是可能产生完全相同的函数选择器的。但在实际开发中，你几乎不需要担心这个问题，主要有两个原因:
    //  概率极低：虽然43亿是有限的，但对于一个常规的智能合约来说，它所包含的函数数量远远不足以让“意外碰撞”的概率变得值得担忧。
    //  编译器的保护：这是最重要的一点。Solidity 编译器会检查在同一个合约（包括其所有父合约）中是否存在函数选择器碰撞。
    function setTargetFunctionRole(
        address target,
        bytes4[] calldata selectors,
        uint64 roleId
    ) public virtual onlyAuthorized {
        for (uint256 i = 0; i < selectors.length; ++i) {
            _setTargetFunctionRole(target, selectors[i], roleId);
        }
    }

    /**
     * @dev {setTargetFunctionRole} 的内部版本，无访问控制。
     *
     * 触发一个 {TargetFunctionRoleUpdated} 事件。
     */
    function _setTargetFunctionRole(address target, bytes4 selector, uint64 roleId) internal virtual {
        _targets[target].allowedRoles[selector] = roleId;
        emit TargetFunctionRoleUpdated(target, selector, roleId);
    }

    /// @inheritdoc IAccessManager
    function setTargetAdminDelay(address target, uint32 newDelay) public virtual onlyAuthorized {
        _setTargetAdminDelay(target, newDelay);
    }

    /**
     * @dev {setTargetAdminDelay} 的内部版本，无访问控制。
     *
     * 触发一个 {TargetAdminDelayUpdated} 事件。
     */
    function _setTargetAdminDelay(address target, uint32 newDelay) internal virtual {
        uint48 effect;
        (_targets[target].adminDelay, effect) = _targets[target].adminDelay.withUpdate(newDelay, minSetback());

        emit TargetAdminDelayUpdated(target, newDelay, effect);
    }

    // =============================================== MODE MANAGEMENT（模式管理） ================================================
    /// @inheritdoc IAccessManager
    function setTargetClosed(address target, bool closed) public virtual onlyAuthorized {
        _setTargetClosed(target, closed);
    }

    /**
     * @dev 为一个合约设置关闭标志。这是一个无访问限制的内部设置器。
     *
     * 触发一个 {TargetClosed} 事件。
     */
    function _setTargetClosed(address target, bool closed) internal virtual {
        _targets[target].closed = closed;
        emit TargetClosed(target, closed);
    }

    // ============================================== DELAYED OPERATIONS（延迟操作） ==============================================
    /// @inheritdoc IAccessManager
    // 检查操作是否已过期
    function getSchedule(bytes32 id) public view virtual returns (uint48) {
        uint48 timepoint = _schedules[id].timepoint;
        return _isExpired(timepoint) ? 0 : timepoint;
    }

    /// @inheritdoc IAccessManager
    function getNonce(bytes32 id) public view virtual returns (uint32) {
        return _schedules[id].nonce;
    }

    /// @inheritdoc IAccessManager
    function schedule(
        address target,
        bytes calldata data,// 经过ABI编码的完整数据
        uint48 when // 执行的时间
    ) public virtual returns (bytes32 operationId, uint32 nonce) {
        address caller = _msgSender();

        // 获取适用于调用者在目标函数上的限制
        (, uint32 setback) = _canCallExtended(caller, target, data);

        uint48 minWhen = Time.timestamp() + setback;

        // 如果带延迟的调用未被授权，或者请求的时间太早，则回滚
        // 只处理必须延迟的操作，从而和 execute函数形成了清晰的功能划分，避免了逻辑上的混乱和误用。
        if (setback == 0 || (when > 0 && when < minWhen)) {
            revert AccessManagerUnauthorizedCall(caller, target, _checkSelector(data));
        }

        // 因堆栈太深而重用变量
        when = uint48(Math.max(when, minWhen)); // 类型转换是安全的：两个输入都是 uint48

        // 如果调用者被授权，则调度操作
        operationId = hashOperation(caller, target, data);

        // 确保操作当前未被调度或已过期
        _checkNotScheduled(operationId);

        unchecked {
            // 在不到1000年的时间里，nonce 不可能溢出
            nonce = _schedules[operationId].nonce + 1;
        }
        _schedules[operationId].timepoint = when;
        _schedules[operationId].nonce = nonce;
        // nonce暴露到线下
        emit OperationScheduled(operationId, nonce, when, caller, target, data);

        // 使用命名返回值，否则会遇到堆栈太深的问题
        // “堆栈太深”衡量的是函数执行的任何一个时间点上，EVM堆栈上同时存在的变量数量。
        // 它的1024上限限制的是数据项（item）的数量，而不是函数调用的层数。
        // EVM 堆栈的深度上限是 1024。如果编译器发现在某个执行路径上，需要的堆栈槽位超过了1024，就会报错。
        // 当你调用另一个函数时，你需要把那个函数的参数也压入堆栈
        // 峰值深度 ≈ 静态占用 + 峰值动态占用
        //  1. 静态占用 (Static Usage)
        //      这是函数在整个生命周期中，为“具名变量”长期占用的槽位。可以大致估算为：
        //      * 函数参数的数量函数参数的数量
        //      * 命名的返回值的数量
        //      * 函数内声明的具名变量的数量
        // 2. 峰值动态占用 (Peak Dynamic Usage)
        //      它是在执行某一条语句时，为了完成计算而临时使用的槽位。峰值通常出现在函数中最复杂的那条语句上。
        //      * 函数调用: 调用 myFunc(a, b, c) 需要临时将 a, b, c 和一个返回地址压入堆栈。
        //      * 嵌套调用: 调用 myFunc(otherFunc(a), b) 时，堆栈会先为 otherFunc 的调用和返回值分配空间，然后再为 myFunc 的调用分配空间，形成“堆叠”。
        //      * 复杂运算: uint x = (a + b) * (c - d); 这种计算会产生很多中间结果，它们也需要临时存放在堆栈上。
    }

    /**
     * @dev 如果操作当前已调度且未过期，则回滚。
     *
     * 注意：此函数是由于 schedule 中的堆栈太深错误而引入的。
     * 为什么拆成子方法能减少堆栈数量?
     *  总的工作量没有减少，但“瞬时”的堆栈峰值占有率降低了。 关键在于作用域（Scope）和堆栈帧（Stack Frame）的生命周期。
     *  拆分成子函数，并不是减少了变量的总数，而是将变量的生命周期切分成了互不重叠的片段。
     *  这使得EVM可以在不同时间点复用同一块堆栈空间，从而极大地降低了在同一时刻所需要的最大堆栈深度。
     */
    function _checkNotScheduled(bytes32 operationId) private view {
        uint48 prevTimepoint = _schedules[operationId].timepoint;
        if (prevTimepoint != 0 && !_isExpired(prevTimepoint)) {
            revert AccessManagerAlreadyScheduled(operationId);
        }
    }

    /// @inheritdoc IAccessManager
    // 重入不是问题，因为权限是在 msg.sender 上检查的。此外，
    // _consumeScheduledOp 保证一个已调度的操作只执行一次。
    // slither-disable-next-line reentrancy-no-eth
    function execute(address target, bytes calldata data) public payable virtual returns (uint32) {
        address caller = _msgSender();

        // 获取适用于调用者在目标函数上的限制
        (bool immediate, uint32 setback) = _canCallExtended(caller, target, data);

        // 如果调用未被授权，则回滚
        if (!immediate && setback == 0) {
            revert AccessManagerUnauthorizedCall(caller, target, _checkSelector(data));
        }

        bytes32 operationId = hashOperation(caller, target, data);
        uint32 nonce;

        // 如果调用者被授权，检查操作是否足够早地被调度
        // 即使当前没有强制延迟，也消耗一个可用的调度
        if (setback != 0 || getSchedule(operationId) != 0) {
            // 包含“消耗一个已调度操作”的完整逻辑（包括检查是否存在、是否到时、是否过期）
            nonce = _consumeScheduledOp(operationId);
        }

        // 将目标和选择器标记为已授权
        bytes32 executionIdBefore = _executionId;
        _executionId = _hashExecutionId(target, _checkSelector(data));

        // 执行调用
        Address.functionCallWithValue(target, data, msg.value);

        // 重置执行标识符
        _executionId = executionIdBefore;

        return nonce;
    }

    /// @inheritdoc IAccessManager
    // 取消已调度的操作
    function cancel(address caller, address target, bytes calldata data) public virtual returns (uint32) {
        address msgsender = _msgSender();
        bytes4 selector = _checkSelector(data);

        bytes32 operationId = hashOperation(caller, target, data);
        if (_schedules[operationId].timepoint == 0) {
            revert AccessManagerNotScheduled(operationId);
        } else if (caller != msgsender) {
            // 调用只能由调度它们的用户、全局管理员或所需角色的守护者取消。
            (bool isAdmin, ) = hasRole(ADMIN_ROLE, msgsender);
            (bool isGuardian, ) = hasRole(getRoleGuardian(getTargetFunctionRole(target, selector)), msgsender);
            if (!isAdmin && !isGuardian) {
                revert AccessManagerUnauthorizedCancel(msgsender, caller, target, selector);
            }
        }

        delete _schedules[operationId].timepoint; // 重置时间点，保留 nonce
        uint32 nonce = _schedules[operationId].nonce;
        emit OperationCanceled(operationId, nonce);

        return nonce;
    }

    /// @inheritdoc IAccessManager
    // consumeScheduledOp 是“拉取（Pull）”模式：你直接去敲目标合约的门，
    // 目标合约自己回头向 AccessManager拉取确认：“刚才敲门这个人，是在你的预约名单上吗？”
    // 允许一个目标合约，在自己的函数内部，主动向 `AccessManager` 核销一个已经调度好的操作，以验证当前收到的这个调用是合法的。
    // 这在一种特定场景下非常有用：当目标合约的函数需要知道原始调用者 `msg.sender` 的身份时。
    function consumeScheduledOp(address caller, bytes calldata data) public virtual {
        address target = _msgSender();
        // 要求: AccessManager 规定，任何想要使用 consumeScheduledOp 拉取模式的合约，都必须继承自 AccessManaged 合约。
        // 这个函数只做一件事：返回它自身的函数选择器。
        if (IAccessManaged(target).isConsumingScheduledOp() != IAccessManaged.isConsumingScheduledOp.selector) {
            revert AccessManagerUnauthorizedConsume(target);
        }
        _consumeScheduledOp(hashOperation(caller, target, data));
    }

    /**
     * @dev {consumeScheduledOp} 的内部变体，操作于 bytes32 operationId。
     *
     * 返回被消耗的已调度操作的 nonce。
     */
    function _consumeScheduledOp(bytes32 operationId) internal virtual returns (uint32) {
        uint48 timepoint = _schedules[operationId].timepoint;
        uint32 nonce = _schedules[operationId].nonce;

        if (timepoint == 0) { // 未调度
            revert AccessManagerNotScheduled(operationId);
        } else if (timepoint > Time.timestamp()) { // 时间未到
            revert AccessManagerNotReady(operationId);
        } else if (_isExpired(timepoint)) { // 已过期
            revert AccessManagerExpired(operationId);
        }

        delete _schedules[operationId].timepoint; // 重置时间点，保留 nonce
        emit OperationExecuted(operationId, nonce);

        return nonce;
    }

    /// @inheritdoc IAccessManager
    function hashOperation(address caller, address target, bytes calldata data) public view virtual returns (bytes32) {
        return keccak256(abi.encode(caller, target, data));
    }

    // ==================================================== OTHERS（其他） ====================================================
    /// @inheritdoc IAccessManager
    function updateAuthority(address target, address newAuthority) public virtual onlyAuthorized {
        IAccessManaged(target).setAuthority(newAuthority);
    }

    // ================================================= ADMIN LOGIC（管理员逻辑） ==================================================
    /**
     * @dev 根据管理员和角色逻辑检查当前调用是否被授权。
     *
     * 警告：请仔细审查 {AccessManaged-restricted} 的注意事项，因为它们适用于此修改器。
     */
    function _checkAuthorized() private {
        address caller = _msgSender();
        (bool immediate, uint32 delay) = _canCallSelf(caller, _msgData());
        if (!immediate) {
            if (delay == 0) { // 没有权限
                (, uint64 requiredRole, ) = _getAdminRestrictions(_msgData());
                revert AccessManagerUnauthorizedAccount(caller, requiredRole);
            } else {
                _consumeScheduledOp(hashOperation(caller, address(this), _msgData()));
            }
        }
    }

    /**
     * @dev 根据涉及的函数和参数，获取给定函数调用的管理员限制。
     *当一个函数调用指向 `AccessManager` 合约自身时，_getAdminRestrictions负责解析这个调用，并判断它是否属于一个受限制的“管理操作”。
     * 返回：
     * - bool restricted: 此数据是否匹配一个受限操作
     * - uint64: 此操作受限于哪个角色
     * - uint32: 为该操作强制执行的最小延迟（操作延迟和管理员执行延迟中的最大值）
     */
    function _getAdminRestrictions(
        bytes calldata data
    ) private view returns (bool adminRestricted, uint64 roleAdminId, uint32 executionDelay) {
        if (data.length < 4) {
            return (false, 0, 0);
        }

        bytes4 selector = _checkSelector(data);

        // 限制为 ADMIN，除了调用者可能有的任何执行延迟外，没有其他延迟
        if (
            selector == this.labelRole.selector ||
            selector == this.setRoleAdmin.selector ||
            selector == this.setRoleGuardian.selector ||
            selector == this.setGrantDelay.selector ||
            selector == this.setTargetAdminDelay.selector
        ) {
            return (true, ADMIN_ROLE, 0);
        }

        // 限制为 ADMIN，并带有与目标相对应的管理延迟
        if (
            selector == this.updateAuthority.selector ||
            selector == this.setTargetClosed.selector ||
            selector == this.setTargetFunctionRole.selector
        ) {
            // 第一个参数是目标地址。
            address target = abi.decode(data[0x04:0x24], (address));
            uint32 delay = getTargetAdminDelay(target);
            return (true, ADMIN_ROLE, delay);
        }

        // 限制为该角色的管理员，除了调用者可能有的任何执行延迟外，没有其他延迟。
        if (selector == this.grantRole.selector || selector == this.revokeRole.selector) {
            // 第一个参数是 roleId。
            uint64 roleId = abi.decode(data[0x04:0x24], (uint64));
            return (true, getRoleAdmin(roleId), 0);
        }

        return (false, getTargetFunctionRole(address(this), selector), 0);
    }

    // =================================================== HELPERS（辅助函数） ====================================================
    /**
     * @dev {canCall} 的扩展版本，供内部使用，当目标是此合约时检查 {_canCallSelf}。
     *
     * 返回：
     * - bool immediate: 操作是否可以立即执行（无延迟）
     * - uint32 delay: 执行延迟
     * 
     * _canCallExtended 为什么不直接返回“是否有权限”？
     *  因为“是否有权限”这个问题本身有三种状态，而不是简单的两种。
     *  一个简单的 bool 只能告诉你“是”或“否”，但这不足以描述 AccessManager 的权限模型。这三种状态是：
     *      1. 允许立即执行: 你有权限，且不需要任何等待。返回 (true, 0)
     *      2. 允许，但需要延迟执行: 你有权限，但你必须先 schedule 并等待一段时间后才能 execute。返回 (false, >0)
     *      3. 完全不允许: 你没有权限，什么也做不了。(false, 0)  
     */
    function _canCallExtended(
        address caller,
        address target,
        bytes calldata data
    ) private view returns (bool immediate, uint32 delay) {
        if (target == address(this)) {
            return _canCallSelf(caller, data);
        } else {
            return data.length < 4 ? (false, 0) : canCall(caller, target, _checkSelector(data));
        }
    }

    /**
     * @dev {canCall} 的一个版本，用于检查此合约中的限制。
     */
    function _canCallSelf(address caller, bytes calldata data) private view returns (bool immediate, uint32 delay) {
        if (data.length < 4) {
            return (false, 0);
        }

        if (caller == address(this)) {
            // 调用者是 AccessManager，这意味着调用是通过 {execute} 发送的，并且已经检查了权限。
            // 我们验证在 {execute} 期间设置的调用“标识符”是否正确。
            return (_isExecuting(address(this), _checkSelector(data)), 0);
        }

        (bool adminRestricted, uint64 roleId, uint32 operationDelay) = _getAdminRestrictions(data);

        // isTargetClosed 应用于非管理员限制的函数
        if (!adminRestricted && isTargetClosed(address(this))) {
            return (false, 0);
        }

        (bool inRole, uint32 executionDelay) = hasRole(roleId, caller);
        if (!inRole) {
            return (false, 0);
        }

        // 向下转型是安全的，因为两个选项都是 uint32
        // 告诉上层调用者，这次操作是否能立即执行，以及需要遵守的最终延迟是多少。
        delay = uint32(Math.max(operationDelay, executionDelay));
        return (delay == 0, delay);
    }

    /**
     * @dev 如果一个带有 `target` 和 `selector` 的调用正在通过 {executed} 执行，则返回 true。
     * 是否正在被执行调用，是通过对比 _executionId 来判断的。
     * 防止重入攻击
     */
    function _isExecuting(address target, bytes4 selector) private view returns (bool) {
        return _executionId == _hashExecutionId(target, selector);
    }

    /**
     * @dev 如果一个调度时间点已超过其过期期限，则返回 true。
     */
    function _isExpired(uint48 timepoint) private view returns (bool) {
        return timepoint + expiration() <= Time.timestamp();
    }

    /**
     * @dev 从 calldata 中提取选择器。如果数据长度不足4字节，则会恐慌（panic）。
     */
    function _checkSelector(bytes calldata data) private pure returns (bytes4) {
        return bytes4(data[0:4]);
    }

    /**
     * @dev 用于执行保护的哈希函数。
     */
    function _hashExecutionId(address target, bytes4 selector) private pure returns (bytes32) {
        return Hashes.efficientKeccak256(bytes32(uint256(uint160(target))), selector);
    }
}
