// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (access/extensions/IAccessControlDefaultAdminRules.sol)

pragma solidity >=0.8.4;

import {IAccessControl} from "../IAccessControl.sol";

/**
 * @dev 为支持ERC-165检测而声明的AccessControlDefaultAdminRules的外部接口。
 */
interface IAccessControlDefaultAdminRules is IAccessControl {
    /**
     * @dev 新的默认管理员不是一个有效的默认管理员。
     */
    error AccessControlInvalidDefaultAdmin(address defaultAdmin);

    /**
     * @dev 至少违反了以下规则之一：
     *
     * - `DEFAULT_ADMIN_ROLE` 只能由其自身管理。
     * - `DEFAULT_ADMIN_ROLE` 在同一时间只能由一个帐户持有。
     * - 任何 `DEFAULT_ADMIN_ROLE` 的转移都必须分两个延迟步骤进行。
     */
    error AccessControlEnforcedDefaultAdminRules();

    /**
     * @dev 转移默认管理员延迟的延迟被强制执行，
     * 操作必须等到 `schedule`。
     *
     * 注意：`schedule` 可以为 0，表示没有计划的转移。
     */
    error AccessControlEnforcedDefaultAdminDelay(uint48 schedule);

    /**
     * @dev 当 {defaultAdmin} 转移开始时触发，将 `newAdmin` 设置为下一个
     * 通过调用 {acceptDefaultAdminTransfer} 成为 {defaultAdmin} 的地址，但仅在 `acceptSchedule`
     * 过后。
     */
    event DefaultAdminTransferScheduled(address indexed newAdmin, uint48 acceptSchedule);

    /**
     * @dev 当一个从未被接受的 {pendingDefaultAdmin} 被重置时触发，无论其计划如何。
     */
    event DefaultAdminTransferCanceled();

    /**
     * @dev 当 {defaultAdminDelay} 更改开始时触发，将 `newDelay` 设置为下一个
     * 在 `effectSchedule` 过后应用于默认管理员转移之间的延迟。
     */
    event DefaultAdminDelayChangeScheduled(uint48 newDelay, uint48 effectSchedule);

    /**
     * @dev 当一个 {pendingDefaultAdminDelay} 的计划没有通过时被重置时触发。
     */
    event DefaultAdminDelayChangeCanceled();

    /**
     * @dev 返回当前 `DEFAULT_ADMIN_ROLE` 持有者的地址。
     */
    function defaultAdmin() external view returns (address);

    /**
     * @dev 返回一个 `newAdmin` 和一个接受计划的元组。
     * 在 `schedule` 过后，`newAdmin` 将能够通过调用 {acceptDefaultAdminTransfer}
     * 接受 {defaultAdmin} 角色，从而完成角色转移。
     * `acceptSchedule` 中的零值表示没有待处理的管理员转移。
     * 
     * 注意：零地址 `newAdmin` 表示正在放弃 {defaultAdmin}。
     */
    function pendingDefaultAdmin() external view returns (address newAdmin, uint48 acceptSchedule);

    /**
     * @dev 返回开始的 {defaultAdmin} 转移接受计划所需的延迟。
     *
     * 在调用 {beginDefaultAdminTransfer} 设置接受计划时，此延迟将添加到当前时间戳。
     *
     * 注意：如果已计划延迟更改，它将在计划通过后立即生效，
     * 使此函数返回新的延迟。参见 {changeDefaultAdminDelay}。
     */
    function defaultAdminDelay() external view returns (uint48);

    /**
     * @dev 返回一个 `newDelay` 和一个生效计划的元组。
     *
     * 在 `schedule` 过后，`newDelay` 将立即对通过 {beginDefaultAdminTransfer}
     * 开始的每个新的 {defaultAdmin} 转移生效。
     *
     * `effectSchedule` 中的零值表示没有待处理的延迟更改。
     *
     * 注意：仅 `newDelay` 的零值表示在生效计划之后，
     * 下一个 {defaultAdminDelay} 将为零。
     */
    function pendingDefaultAdminDelay() external view returns (uint48 newDelay, uint48 effectSchedule);

    /**
     * @dev 通过设置一个在当前时间戳加上 {defaultAdminDelay} 之后
     * 计划接受的 {pendingDefaultAdmin} 来开始 {defaultAdmin} 转移。
     *
     * 要求：
     *
     * - 只能由当前 {defaultAdmin} 调用。
     *
     * 触发 DefaultAdminRoleChangeStarted 事件。
     */
    function beginDefaultAdminTransfer(address newAdmin) external;

    /**
     * @dev 取消先前通过 {beginDefaultAdminTransfer} 开始的 {defaultAdmin} 转移。
     *
     * 尚未接受的 {pendingDefaultAdmin} 也可以通过此函数取消。
     *
     * 要求：
     *
     * - 只能由当前 {defaultAdmin} 调用。
     *
     * 可能触发 DefaultAdminTransferCanceled 事件。
     */
    function cancelDefaultAdminTransfer() external;

    /**
     * @dev 完成先前通过 {beginDefaultAdminTransfer} 开始的 {defaultAdmin} 转移。
     *
     * 调用函数后：
     *
     * - `DEFAULT_ADMIN_ROLE` 应授予调用者。
     * - `DEFAULT_ADMIN_ROLE` 应从前一个持有者那里撤销。
     * - {pendingDefaultAdmin} 应重置为零值。
     *
     * 要求：
     *
     * - 只能由 {pendingDefaultAdmin} 的 `newAdmin` 调用。
     * - {pendingDefaultAdmin} 的 `acceptSchedule` 应该已经过去。
     */
    function acceptDefaultAdminTransfer() external;

    /**
     * @dev 通过设置一个在当前时间戳加上 {defaultAdminDelay} 之后
     * 计划生效的 {pendingDefaultAdminDelay} 来启动 {defaultAdminDelay} 更新。
     *
     * 此函数保证，在此方法被调用的时间戳和 {pendingDefaultAdminDelay}
     * 生效计划之间完成的任何对 {beginDefaultAdminTransfer} 的调用，
     * 都将使用调用前设置的当前 {defaultAdminDelay}。
     *
     * {pendingDefaultAdminDelay} 的生效计划的定义方式是，
     * 等到计划时间然后用新的延迟调用 {beginDefaultAdminTransfer}，
     * 将至少花费与另一次完整的 {defaultAdmin} 转移（包括接受）相同的时间。
     *
     * 该计划专为两种情况设计：
     *
     * - 当延迟更改为更长时，计划是 `block.timestamp + newDelay`，上限为 {defaultAdminDelayIncreaseWait}。
     * - 当延迟更改为更短时，计划是 `block.timestamp + (current delay - new delay)`。
     *
     * 一个从未生效的 {pendingDefaultAdminDelay} 将被取消，以支持新的计划更改。
     *
     * 要求：
     *
     * - 只能由当前 {defaultAdmin} 调用。
     *
     * 触发 DefaultAdminDelayChangeScheduled 事件，并可能触发 DefaultAdminDelayChangeCanceled 事件。
     */
    function changeDefaultAdminDelay(uint48 newDelay) external;

    /**
     * @dev 取消计划的 {defaultAdminDelay} 更改。
     *
     * 要求：
     *
     * - 只能由当前 {defaultAdmin} 调用。
     *
     * 可能触发 DefaultAdminDelayChangeCanceled 事件。
     */
    function rollbackDefaultAdminDelay() external;

    /**
     * @dev {defaultAdminDelay} 增加（即使用 {changeDefaultAdminDelay} 计划的）生效的最长时间（秒）。默认为 5 天。
     *
     * 当 {defaultAdminDelay} 计划增加时，它会在新延迟过去后生效，
     * 目的是为恢复任何意外更改（例如使用毫秒而不是秒）留出足够的时间，
     * 这可能会锁定合约。但是，为避免过多的计划，等待时间由此函数限制，
     * 并且可以为自定义的 {defaultAdminDelay} 增加计划重写它。
     *
     * 重要提示：重写此值时，请确保添加合理的时间量，否则，
     * 如果输入错误（例如设置毫秒而不是秒），则存在设置高新延迟的风险，
     * 该延迟几乎立即生效，而没有人工干预的可能性。
     */
    function defaultAdminDelayIncreaseWait() external view returns (uint48);
}
