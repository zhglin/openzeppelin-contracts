// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (account/extensions/draft-AccountERC7579Hooked.sol)

pragma solidity ^0.8.26;

import {IERC7579Hook, MODULE_TYPE_HOOK} from "../../interfaces/draft-IERC7579.sol";
import {ERC7579Utils, Mode} from "../../account/utils/draft-ERC7579Utils.sol";
import {AccountERC7579} from "./draft-AccountERC7579.sol";

/**
 * @dev {AccountERC7579} 的扩展，支持单个钩子模块（类型 4）。
 *
 * 如果安装了钩子模块，此扩展将在使用 {_execute} 执行任何操作（默认包括 {execute} 和 {executeFromExecutor}）之前调用钩子模块的
 * {IERC7579Hook-preCheck}，并在之后调用 {IERC7579Hook-postCheck}。
 *
 * 注意：钩子模块打破了检查-效果-交互模式。特别是，{IERC7579Hook-preCheck} 钩子可能导致潜在的危险重入。
 * 如果在 preHook 之前或 postHook 之后没有执行任何效果，则使用 `withHook()` 修饰符是安全的。
 * 在此处的函数中就是这种情况，但如果带有此修饰符的函数被覆盖，则可能不是这种情况。
 * 开发者在实现钩子模块或进一步覆盖涉及钩子的函数时应极其小心。
 */
/*
    钩子模块的用途和好处
    钩子模块提供了极大的灵活性，可以用于实现各种高级功能：
        * 预执行检查：
            * 安全策略：在任何操作执行前，检查是否满足额外的安全条件（例如，是否在白名单时间段内，是否满足特定的链上状态）。
            * 消费限额：检查账户是否超出了每日/每笔交易的消费限额。
            * 上下文验证：验证交易的 msg.sender、msg.value 或 msg.data 是否符合预期。
        * 后执行操作：
            * 日志记录：在操作完成后记录详细的执行日志。
            * 状态更新：根据操作结果更新账户的内部状态或外部合约的状态。
            * 事件触发：在操作完成后触发特定的事件。
            
    AccountERC7579Hooked 提供了一个强大的机制，允许 ERC-7579 智能账户在关键操作执行前后插入自定义逻辑。
    这极大地增强了账户的可编程性和灵活性，但也引入了潜在的安全风险，需要开发者在设计和实现时格外注意。 
*/
abstract contract AccountERC7579Hooked is AccountERC7579 {
    address private _hook;

    /// @dev 钩子模块已存在。此合约仅支持一个钩子模块。
    error ERC7579HookModuleAlreadyPresent(address hook);

    /**
     * @dev 在执行修改后的函数之前调用 {IERC7579Hook-preCheck}，并在之后调用 {IERC7579Hook-postCheck}。
     */
    modifier withHook() {
        address hook_ = hook();
        bytes memory hookData;

        // slither-disable-next-line reentrancy-no-eth
        if (hook_ != address(0)) hookData = IERC7579Hook(hook_).preCheck(msg.sender, msg.value, msg.data);
        _;
        if (hook_ != address(0)) IERC7579Hook(hook_).postCheck(hookData);
    }

    /// @inheritdoc AccountERC7579
    function accountId() public view virtual override returns (string memory) {
        // 供应商名称.账户名称.语义化版本
        return "@openzeppelin/community-contracts.AccountERC7579Hooked.v0.0.0";
    }

    /// @dev 如果已安装，则返回钩子模块地址，否则返回 `address(0)`。
    function hook() public view virtual returns (address) {
        return _hook;
    }

    /// @dev 支持钩子模块。参见 {AccountERC7579-supportsModule}
    function supportsModule(uint256 moduleTypeId) public view virtual override returns (bool) {
        return moduleTypeId == MODULE_TYPE_HOOK || super.supportsModule(moduleTypeId);
    }

    /// @inheritdoc AccountERC7579
    function isModuleInstalled(
        uint256 moduleTypeId,
        address module,
        bytes calldata data
    ) public view virtual override returns (bool) {
        return
            (moduleTypeId == MODULE_TYPE_HOOK && module == hook()) ||
            super.isModuleInstalled(moduleTypeId, module, data);
    }

    /// @dev 安装支持钩子模块的模块。参见 {AccountERC7579-_installModule}
    function _installModule(
        uint256 moduleTypeId,
        address module,
        bytes memory initData
    ) internal virtual override withHook {
        if (moduleTypeId == MODULE_TYPE_HOOK) {
            require(_hook == address(0), ERC7579HookModuleAlreadyPresent(_hook));
            _hook = module;
        }
        super._installModule(moduleTypeId, module, initData);
    }

    /// @dev 卸载支持钩子模块的模块。参见 {AccountERC7579-_uninstallModule}
    function _uninstallModule(
        uint256 moduleTypeId,
        address module,
        bytes memory deInitData
    ) internal virtual override withHook {
        if (moduleTypeId == MODULE_TYPE_HOOK) {
            require(_hook == module, ERC7579Utils.ERC7579UninstalledModule(moduleTypeId, module));
            _hook = address(0);
        }
        super._uninstallModule(moduleTypeId, module, deInitData);
    }

    /// @dev {AccountERC7579-_execute} 的钩子版本。
    // 提供给execute和executeFromExecutor函数使用
    function _execute(
        Mode mode,
        bytes calldata executionCalldata
    ) internal virtual override withHook returns (bytes[] memory) {
        return super._execute(mode, executionCalldata);
    }

    /// @dev {AccountERC7579-_fallback} 的钩子版本。
    function _fallback() internal virtual override withHook returns (bytes memory) {
        return super._fallback();
    }
}
