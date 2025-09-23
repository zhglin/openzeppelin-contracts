// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (account/extensions/draft-ERC7821.sol)

pragma solidity ^0.8.20;

import {ERC7579Utils, Mode, CallType, ExecType, ModeSelector} from "../utils/draft-ERC7579Utils.sol";
import {IERC7821} from "../../interfaces/draft-IERC7821.sol";
import {Account} from "../Account.sol";

/**
 * @dev 遵循 ERC-7821 的最小化批量执行器。
 *
 * 仅支持单一批处理模式 (`0x01000000000000000000`)。不支持可选的 "opData"。
 *
 * @custom:stateless
 */
abstract contract ERC7821 is IERC7821 {
    using ERC7579Utils for *;

    error UnsupportedExecutionMode();

    /**
     * @dev 在 `executionData` 中执行调用，不支持可选的 `opData`。
     *
     * 注意：对此函数的访问由 {_erc7821AuthorizedExecutor} 控制。更改访问权限，
     * 例如批准 ERC-4337 入口点的调用，应通过重写它来实现。
     *
     * 如果任何调用失败，则回滚并冒泡错误。
     * 
     * executionData 和 mode 参数的设计非常精巧，共同构成了一套标准化的指令系统。
     * 简单来说：
     *    executionData 负责回答 “做什么” (What)。
     *    mode 负责回答 “怎么做” (How)。
     * 
     * executionData 是struct Execution {
            address target; // 目标合约地址
            uint256 value;  // 发送的 ETH 数量
            bytes callData; // abi.encodeCall(合约方法)
        }[] calls 的 abi 编码。
        draft-IERC7579.sol#L105
     */
    function execute(bytes32 mode, bytes calldata executionData) public payable virtual {
        // 访问控制,谁能调用这个 execute 函数
        if (!_erc7821AuthorizedExecutor(msg.sender, mode, executionData))
            revert Account.AccountUnauthorized(msg.sender);
        // 支持的模式
        if (!supportsExecutionMode(mode)) revert UnsupportedExecutionMode();
        // 执行调用
        executionData.execBatch(ERC7579Utils.EXECTYPE_DEFAULT);
    }

    /// @inheritdoc IERC7821
    /*
        用来检测一个智能账户是否支持某种特定执行模式 (`mode`) 的。
            1. `callType` 必须是 `CALLTYPE_BATCH`: 它只支持批量调用模式。如果你传入一个表示“单次调用”的 mode，它会返回 false。
            2. `execType` 必须是 `EXECTYPE_DEFAULT`: 它只支持“一个失败，全部回滚”的默认执行模式。如果你传入一个表示“try-catch”的 mode，它会返回 false。
            3. `modeSelector` 必须是 `0x00000000`: 它只支持不包含 opData 的最简单模式。
                如果你传入一个表示“我将在 executionData 中提供 opData” 的mode，它会返回 false。
        这个 ERC7821.sol 扩展，只支持一种、也是最基础的一种模式——不带可选数据的、原子性的批量调用。
        实际应用流程:
            1. 一个 DApp 想要让用户的钱包执行两个操作。
            2. DApp 准备了一个 mode = 0x01000000...。
            3. DApp 通过 eth_call 调用用户钱包地址的 supportsExecutionMode(mode) 函数。
            4. 用户的钱包（如果使用了 OpenZeppelin 的这个实现）会返回 true。
            5. DApp 得到肯定的答复后，就放心地构建 UserOperation，让用户签名并发送。
    */
    function supportsExecutionMode(bytes32 mode) public view virtual returns (bool result) {
        (CallType callType, ExecType execType, ModeSelector modeSelector, ) = Mode.wrap(mode).decodeMode();
        return
            callType == ERC7579Utils.CALLTYPE_BATCH &&      // 调用类型必须是“批量”
            execType == ERC7579Utils.EXECTYPE_DEFAULT &&    // 执行类型必须是“默认”
            modeSelector == ModeSelector.wrap(0x00000000);  // 模式选择器必须是“不支持opData”
    }

    /**
     * @dev {execute} 函数的访问控制机制。
     * 默认情况下，只允许合约自身执行。
     *
     * 重写此函数以实现自定义访问控制，例如允许ERC-4337 入口点执行。
     *
     * ```solidity
     * function _erc7821AuthorizedExecutor(
     *   address caller,
     *   bytes32 mode,
     *   bytes calldata executionData
     * ) internal view virtual override returns (bool) {
     *   return caller == address(entryPoint()) || super._erc7821AuthorizedExecutor(caller, mode, executionData);
     * }
     * ```
     */
    function _erc7821AuthorizedExecutor(
        address caller,
        bytes32 /* mode */,
        bytes calldata /* executionData */
    ) internal view virtual returns (bool) {
        return caller == address(this);
    }
}
