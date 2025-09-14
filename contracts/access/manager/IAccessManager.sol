// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (最后更新于 v5.4.0) (access/manager/IAccessManager.sol)

pragma solidity >=0.8.4;

interface IAccessManager {
    /**
     * @dev 一个延迟操作已被调度。
     */
    event OperationScheduled(
        bytes32 indexed operationId,
        uint32 indexed nonce,
        uint48 schedule,
        address caller,
        address target,
        bytes data
    );

    /**
     * @dev 一个已调度的操作已被执行。
     */
    event OperationExecuted(bytes32 indexed operationId, uint32 indexed nonce);

    /**
     * @dev 一个已调度的操作已被取消。
     */
    event OperationCanceled(bytes32 indexed operationId, uint32 indexed nonce);

    /**
     * @dev 为一个 roleId 提供信息性标签。
     */
    event RoleLabel(uint64 indexed roleId, string label);

    /**
     * @dev 当 `account` 被授予 `roleId` 时触发。
     *
     * 注意：`since` 参数的含义取决于 `newMember` 参数。
     * 如果角色被授予一个新成员，`since` 参数表示该账户成为角色成员的时间，
     * 否则它表示此账户和 roleId 的执行延迟被更新。
     */
    event RoleGranted(uint64 indexed roleId, address indexed account, uint32 delay, uint48 since, bool newMember);

    /**
     * @dev 当 `account` 的成员资格或 `roleId` 被撤销时触发。与授予不同，撤销是即时的。
     */
    event RoleRevoked(uint64 indexed roleId, address indexed account);

    /**
     * @dev 作为给定 `roleId` 管理员的角色被更新。
     */
    event RoleAdminChanged(uint64 indexed roleId, uint64 indexed admin);

    /**
     * @dev 作为给定 `roleId` 守护者的角色被更新。
     */
    event RoleGuardianChanged(uint64 indexed roleId, uint64 indexed guardian);

    /**
     * @dev 给定 `roleId` 的授予延迟将在达到 `since` 时间点时更新为 `delay`。
     */
    event RoleGrantDelayChanged(uint64 indexed roleId, uint32 delay, uint48 since);

    /**
     * @dev 目标模式被更新 (true = 关闭, false = 开放)。
     */
    event TargetClosed(address indexed target, bool closed);

    /**
     * @dev 在 `target` 上调用 `selector` 所需的角色被更新为 `roleId`。
     */
    event TargetFunctionRoleUpdated(address indexed target, bytes4 selector, uint64 indexed roleId);

    /**
     * @dev 给定 `target` 的管理延迟将在达到 `since` 时间点时更新为 `delay`。
     */
    event TargetAdminDelayUpdated(address indexed target, uint32 delay, uint48 since);

    error AccessManagerAlreadyScheduled(bytes32 operationId);
    error AccessManagerNotScheduled(bytes32 operationId);
    error AccessManagerNotReady(bytes32 operationId);
    error AccessManagerExpired(bytes32 operationId);
    error AccessManagerLockedRole(uint64 roleId);
    error AccessManagerBadConfirmation();
    error AccessManagerUnauthorizedAccount(address msgsender, uint64 roleId);
    error AccessManagerUnauthorizedCall(address caller, address target, bytes4 selector);
    error AccessManagerUnauthorizedConsume(address target);
    error AccessManagerUnauthorizedCancel(address msgsender, address caller, address target, bytes4 selector);
    error AccessManagerInvalidInitialAdmin(address initialAdmin);

    /**
     * @dev 检查一个地址 (`caller`) 是否被授权直接调用给定合约上的给定函数（无限制）。
     * 此外，它还返回通过 {schedule} 和 {execute} 工作流间接执行调用所需的延迟。
     *
     * 此函数通常由目标合约调用，以控制受限函数的立即执行。
     * 因此，只有在可以无任何延迟地执行调用时，我们才返回 true。如果调用受到先前设置的延迟（非零）的限制，
     * 则该函数应返回 false，并且调用者应调度该操作以供将来执行。
     *
     * 如果 `allowed` 为 true，则可以忽略延迟，并可立即执行操作，否则，
     * 当且仅当延迟大于0时，才可以执行该操作。
     *
     * 注意：IAuthority 接口不包含 `uint32` 延迟。这是对该接口的向后兼容扩展。
     * 因此，某些合约可能会忽略第二个返回参数。在这种情况下，它们将无法识别间接工作流，
     * 并将需要延迟的调用视为被禁止。
     *
     * 注意：此函数不报告管理器本身的管理员函数的权限。这些由 {AccessManager} 文档定义。
     */
    function canCall(
        address caller,
        address target,
        bytes4 selector
    ) external view returns (bool allowed, uint32 delay);

    /**
     * @dev 已调度提案的过期延迟。默认为1周。
     *
     * 重要提示：避免用0覆盖过期时间。否则，每个合约提案都将立即过期，
     * 从而禁用任何调度用法。
     */
    function expiration() external view returns (uint32);

    /**
     * @dev 除执行延迟外，所有延迟更新的最小生效间隔。
     * 它可以无间隔地增加（并在意外增加的情况下通过 {revokeRole} 重置）。默认为5天。
     */
    function minSetback() external view returns (uint32);

    /**
     * @dev 获取合约是否已关闭，从而禁用任何访问。否则，将应用角色权限。
     *
     * 注意：当管理器本身关闭时，管理员函数仍然可以访问，以避免锁定合约。
     */
    function isTargetClosed(address target) external view returns (bool);

    /**
     * @dev 获取调用函数所需的角色。
     */
    function getTargetFunctionRole(address target, bytes4 selector) external view returns (uint64);

    /**
     * @dev 获取目标合约的管理延迟。对合约配置的更改受此延迟的限制。
     */
    function getTargetAdminDelay(address target) external view returns (uint32);

    /**
     * @dev 获取作为给定角色管理员的角色ID。
     *
     * 授予角色、撤销角色以及更新执行延迟以执行受此角色限制的操作都需要管理员权限。
     */
    function getRoleAdmin(uint64 roleId) external view returns (uint64);

    /**
     * @dev 获取作为给定角色守护者的角色。
     *
     * 守护者权限允许取消已根据该角色调度的操作。
     */
    function getRoleGuardian(uint64 roleId) external view returns (uint64);

    /**
     * @dev 获取角色当前的授予延迟。
     *
     * 在调用 {setGrantDelay} 后，其值可能在任何时候更改而不会触发事件。
     * 此值的更改，包括生效时间点，会通过 {RoleGrantDelayChanged} 事件提前通知。
     */
    function getRoleGrantDelay(uint64 roleId) external view returns (uint32);

    /**
     * @dev 获取给定角色下给定账户的访问详情。这些详情包括成员资格生效的时间点，
     * 以及此用户需要此权限级别的所有操作所应用的延迟。
     *
     * 返回：
     * [0] 账户成员资格生效的时间戳。0 表示未授予角色。
     * [1] 账户当前的执行延迟。
     * [2] 账户待处理的执行延迟。
     * [3] 待处理执行延迟将生效的时间戳。0 表示没有已调度的延迟更新。
     */
    function getAccess(
        uint64 roleId,
        address account
    ) external view returns (uint48 since, uint32 currentDelay, uint32 pendingDelay, uint48 effect);

    /**
     * @dev 检查给定账户当前是否具有与给定角色对应的权限级别。请注意，此权限可能与执行延迟相关联。
     * {getAccess} 可以提供更多详情。
     */
    function hasRole(uint64 roleId, address account) external view returns (bool isMember, uint32 executionDelay);

    /**
     * @dev 为角色添加标签，以提高UI对角色的可发现性。
     *
     * 要求：
     *
     * - 调用者必须是全局管理员
     *
     * 触发一个 {RoleLabel} 事件。
     */
    function labelRole(uint64 roleId, string calldata label) external;

    /**
     * @dev 将 `account` 添加到 `roleId`，或更改其执行延迟。
     *
     * 这授予账户调用任何受此角色限制的函数的权限。可以设置一个可选的执行延迟（以秒为单位）。
     * 如果该延迟不为0，则用户需要调度任何受此角色成员限制的操作。
     * 用户只有在延迟过后、操作过期前才能执行该操作。在此期间，管理员和守护者可以取消该操作（参见 {cancel}）。
     *
     * 如果账户已被授予此角色，则执行延迟将被更新。此更新不是即时的，并遵循延迟规则。
     * 例如，如果一个用户当前的延迟是3小时，而调用此函数将延迟减少到1小时，则新延迟需要一些时间才能生效，
     * 以确保在此更新后的3小时内执行的任何操作确实是在此更新之前调度的。
     *
     * 要求：
     *
     * - 调用者必须是该角色的管理员（参见 {getRoleAdmin}）
     * - 授予的角色不能是 `PUBLIC_ROLE`
     *
     * 触发一个 {RoleGranted} 事件。
     */
    function grantRole(uint64 roleId, address account, uint32 executionDelay) external;

    /**
     * @dev 从一个角色中移除一个账户，立即生效。如果账户没有该角色，此调用无效。
     *
     * 要求：
     *
     * - 调用者必须是该角色的管理员（参见 {getRoleAdmin}）
     * - 撤销的角色不能是 `PUBLIC_ROLE`
     *
     * 如果账户拥有该角色，则触发一个 {RoleRevoked} 事件。
     */
    function revokeRole(uint64 roleId, address account) external;

    /**
     * @dev 调用账户放弃角色权限，立即生效。如果发送者不在该角色中，此调用无效。
     *
     * 要求：
     *
     * - 调用者必须是 `callerConfirmation`。
     *
     * 如果账户拥有该角色，则触发一个 {RoleRevoked} 事件。
     */
    function renounceRole(uint64 roleId, address callerConfirmation) external;

    /**
     * @dev 更改给定角色的管理员角色。
     *
     * 要求：
     *
     * - 调用者必须是全局管理员
     *
     * 触发一个 {RoleAdminChanged} 事件
     */
    function setRoleAdmin(uint64 roleId, uint64 admin) external;

    /**
     * @dev 更改给定角色的守护者角色。
     *
     * 要求：
     *
     * - 调用者必须是全局管理员
     *
     * 触发一个 {RoleGuardianChanged} 事件
     */
    function setRoleGuardian(uint64 roleId, uint64 guardian) external;

    /**
     * @dev 更新授予 `roleId` 的延迟。
     *
     * 要求：
     *
     * - 调用者必须是全局管理员
     *
     * 触发一个 {RoleGrantDelayChanged} 事件。
     */
    function setGrantDelay(uint64 roleId, uint32 newDelay) external;

    /**
     * @dev 设置调用 `target` 合约中由 `selectors` 标识的函数所需的角色。
     *
     * 要求：
     *
     * - 调用者必须是全局管理员
     *
     * 每个选择器触发一个 {TargetFunctionRoleUpdated} 事件。
     */
    function setTargetFunctionRole(address target, bytes4[] calldata selectors, uint64 roleId) external;

    /**
     * @dev 设置更改给定目标合约配置的延迟。
     *
     * 要求：
     *
     * - 调用者必须是全局管理员
     *
     * 触发一个 {TargetAdminDelayUpdated} 事件。
     */
    function setTargetAdminDelay(address target, uint32 newDelay) external;

    /**
     * @dev 为一个合约设置关闭标志。
     *
     * 关闭管理器本身不会禁用对管理员方法的访问，以避免锁定合约。
     *
     * 要求：
     *
     * - 调用者必须是全局管理员
     *
     * 触发一个 {TargetClosed} 事件。
     */
    function setTargetClosed(address target, bool closed) external;

    /**
     * @dev 返回一个已调度操作将准备好执行的时间点。如果操作尚未调度、已过期、已执行或已取消，则返回0。
     */
    function getSchedule(bytes32 id) external view returns (uint48);

    /**
     * @dev 返回具有给定id的最新调度操作的nonce。如果操作从未被调度，则返回0。
     */
    function getNonce(bytes32 id) external view returns (uint32);

    /**
     * @dev 调度一个延迟操作以供将来执行，并返回操作标识符。只要满足调用者所需的执行延迟，
     * 就可以选择操作变为可执行的时间戳。特殊值零将自动设置为最早可能的时间。
     *
     * 返回被调度的 `operationId`。由于此值是参数的哈希，当使用相同参数时可能会重复出现；
     * 如果这很重要，返回的 `nonce` 可用于在 {execute} 和 {cancel} 的调用中唯一地标识此调度操作，以区别于同一 `operationId` 的其他出现。
     *
     * 触发一个 {OperationScheduled} 事件。
     *
     * 注意：不能同时调度多个具有相同 `target` 和 `data` 的操作。如果需要这样做，
     * 可以在 `data` 后附加一个随机字节作为盐，如果目标合约使用标准的Solidity ABI编码，则该盐将被忽略。
     */
    function schedule(
        address target,
        bytes calldata data,
        uint48 when
    ) external returns (bytes32 operationId, uint32 nonce);

    /**
     * @dev 执行一个受延迟限制的函数，前提是它已事先正确调度，或者执行延迟为0。
     *
     * 返回被执行的先前调度操作的nonce，如果操作未曾调度（如果调用者没有执行延迟），则返回0。
     *
     * 仅当调用被调度并延迟时，才触发一个 {OperationExecuted} 事件。
     */
    function execute(address target, bytes calldata data) external payable returns (uint32);

    /**
     * @dev 取消一个已调度（延迟）的操作。返回被取消的先前调度操作的nonce。
     *
     * 要求：
     *
     * - 调用者必须是提议者、目标函数的守护者或全局管理员
     *
     * 触发一个 {OperationCanceled} 事件。
     */
    function cancel(address caller, address target, bytes calldata data) external returns (uint32);

    /**
     * @dev 消费一个以调用者为目标的已调度操作。如果存在这样的操作，则将其标记为已消费
     * （触发一个 {OperationExecuted} 事件并清理状态）。否则，抛出一个错误。
     *
     * 这对于希望强制要求以它们为目标的调用已在管理器上调度（及其所包含的所有验证）的合约很有用。
     *
     * 触发一个 {OperationExecuted} 事件。
     */
    function consumeScheduledOp(address caller, bytes calldata data) external;

    /**
     * @dev 延迟操作的哈希函数。
     */
    function hashOperation(address caller, address target, bytes calldata data) external view returns (bytes32);

    /**
     * @dev 更改此管理器实例所管理的目标的权限合约。
     *
     * 要求：
     *
     * - 调用者必须是全局管理员
     */
    function updateAuthority(address target, address newAuthority) external;
}
