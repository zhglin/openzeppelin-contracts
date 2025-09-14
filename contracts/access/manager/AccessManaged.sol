// SPDX-License-Identifier: MIT
// OpenZeppelin 合约（最后更新于 v5.4.0）(access/manager/AccessManaged.sol)

pragma solidity ^0.8.20;

import {AuthorityUtils} from "./AuthorityUtils.sol";
import {IAccessManager} from "./IAccessManager.sol";
import {IAccessManaged} from "./IAccessManaged.sol";
import {Context} from "../../utils/Context.sol";

/**
 * @dev 此合约模块提供了一个 {restricted} 修饰器。使用此修饰器修饰的函数将
 * 根据一个“权限”进行许可：“权限”是一个类似于 {AccessManager} 的合约，它遵循 {IAuthority} 接口，
 * 实现一个允许某些调用者访问某些函数的策略。
 *
 * 重要提示：`restricted` 修饰器绝不应用于 `internal` 函数，在 `public` 函数中应审慎使用，
 * 理想情况下仅用于 `external` 函数。请参阅 {restricted}。
 */
/**
 * 1. 部署 `AccessManager` 合约：
 *  您需要先独立部署一个 AccessManager 合约。在部署时，通常会指定一个初始的管理员地址，这个管理员拥有配置该 AccessManager 的最高权限。
 * 2. 配置 `AccessManager`（设置角色和权限）：
 *  AccessManager 部署成功后，它的管理员就需要调用它内部的函数来设置权限规则。这包括：
 *      定义角色（Role）：例如创建 ADMIN_ROLE、TREASURY_ROLE 等不同的角色。
 *      授予角色：将定义好的角色授予给不同的用户地址（钱包地址或合约地址）。
 *      设置权限：规定某个角色可以调用哪个合约的哪个函数。
 *  3. 部署您的主合约
 */
/**
 * Treasury.withdraw() 被 AccessManager 设置为需要 1 天的延迟。
 * 您已经在 `AccessManager` 上调用了 schedule 来预约一个提款操作。
 * 现在，1 天已经过去。
 * 您调用 `Treasury.withdraw()` 函数，尝试执行这个预约。
 */
abstract contract AccessManaged is Context, IAccessManaged {
    // 通常是一个 AccessManager 合约的地址
    address private _authority;

    bool private _consumingSchedule;

    /**
     * @dev 初始化连接到初始权限的合约。
     */
    constructor(address initialAuthority) {
        _setAuthority(initialAuthority);
    }

    /**
     * @dev 根据连接的权限、此合约以及进入合约的函数的调用者和选择器，
     * 限制对函数的访问。
     *
     * [重要提示]
     * ====
     * 通常，此修饰器只应在 `external` 函数上使用。可以将其用于作为外部入口点
     * 且不在内部调用的 `public` 函数。除非您清楚自己在做什么，否则绝不应在 `internal`
     * 函数上使用它。不遵守这些规则可能会产生严重的安全隐患！这是因为权限是由
     * 进入合约的函数（即调用堆栈底部的函数）决定的，而不是在源代码中可以看到
     * 修饰器的函数。
     * ====
     *
     * [警告]
     * ====
     * 避免将此修饰器添加到 https://docs.soliditylang.org/en/v0.8.20/contracts.html#receive-ether-function[`receive()`]
     * 函数或 https://docs.soliditylang.org/en/v0.8.20/contracts.html#fallback-function[`fallback()`] 函数。这些
     * 函数是唯一无法从 calldata 中明确确定函数选择器的执行路径，
     * 因为在 `receive()` 函数中选择器默认为 `0x00000000`，如果在 `fallback()` 函数中
     * 未提供 calldata，情况也类似。（请参阅 {_checkCanCall}）。
     *
     * `receive()` 函数将始终 panic，而 `fallback()` 函数可能会根据 calldata 的长度 panic。
     * ====
     * 
     * `AccessManaged` (执行者)：它不关心复杂的规则。它只负责：
     *      1. 问 AccessManager 能不能立即过。
     *      2. 如果不能，但被告知有延迟，它就再请求 AccessManager 去“核销一个预约”。
     * `AccessManager` (决策者)：它掌握所有规则，负责：
     *      1. 回答“能否立即过”的询问。
     *      2. 提供“预约”（schedule）功能。
     *      3. 提供“核销预约”（consumeScheduledOp）功能，供 AccessManaged 在第二阶段调用。
     */
    modifier restricted() {
        _checkCanCall(_msgSender(), _msgData());
        _;
    }

    /// @inheritdoc IAccessManaged
    function authority() public view virtual returns (address) {
        return _authority;
    }

    /// @inheritdoc IAccessManaged
    function setAuthority(address newAuthority) public virtual {
        address caller = _msgSender();
        if (caller != authority()) {
            revert AccessManagedUnauthorized(caller);
        }
        // 必须是一个合约地址
        if (newAuthority.code.length == 0) {
            revert AccessManagedInvalidAuthority(newAuthority);
        }
        _setAuthority(newAuthority);
    }

    /// @inheritdoc IAccessManaged
    function isConsumingScheduledOp() public view returns (bytes4) {
        return _consumingSchedule ? this.isConsumingScheduledOp.selector : bytes4(0);
    }

    /**
     * @dev 将控制权转移给新的权限。内部函数，无访问限制。允许绕过
     * 当前权限设置的权限。
     */
    function _setAuthority(address newAuthority) internal virtual {
        _authority = newAuthority;
        emit AuthorityUpdated(newAuthority);
    }

    /**
     * @dev 如果调用者不允许调用由选择器标识的函数，则回滚。如果 calldata小于 4 字节，则 panic。
     */
    function _checkCanCall(address caller, bytes calldata data) internal virtual {
        (bool immediate, uint32 delay) = AuthorityUtils.canCallWithDelay(
            authority(),
            caller,
            address(this),
            bytes4(data[0:4])
        );
        if (!immediate) {
            if (delay > 0) { // 有权限,存在延迟
                _consumingSchedule = true;
                IAccessManager(authority()).consumeScheduledOp(caller, data);
                _consumingSchedule = false;
            } else {
                revert AccessManagedUnauthorized(caller);
            }
        }
    }
}
