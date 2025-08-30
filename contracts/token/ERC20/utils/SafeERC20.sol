// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../IERC20.sol";
import {IERC1363} from "../../../interfaces/IERC1363.sol";

/**
 * @title SafeERC20
 * @dev 对 ERC-20 操作的包装器，当操作失败时（即代币合约返回 false）会抛出异常。
 * 对于那些在失败时不返回值（而是 revert 或 throw）的代币，本库也同样支持，此时只要调用没有 revert 就被假定为成功。
 * 要使用此库，你可以在你的合约中添加一条 `using SafeERC20 for IERC20;` 语句，
 * 这样你就可以像 `token.safeTransfer(...)` 一样调用这些安全操作了。
 */
/**
 *  (bool success, bytes memory data) = token.call(abi.encodeWithSignature("transfer(address,uint256)", to, value));
 *  这个调用会返回两个值：
 *      success: 一个 bool 值，表示调用是否 revert。
 *      data: 一个 bytes memory 数组，包含了对方合约返回的完整数据。
 *  它的问题在于内存（memory）的分配和开销。
 *  为了接收返回数据 data，EVM 必须在内存中开辟一块新的、大小不定的空间来存储它。
 *  无论你是否需要用到 `data` 的内容，这个内存分配的 Gas 开销是省不掉的。
 *  
 *  SafeERC20 使用的内联汇编则像一个“外科手术医生”，它对内存的使用极其精准和吝啬。
 *  们来看它的处理方式：
 *  1. 它执行 call，返回值（如果有的话）会被放在一块临时的“草稿空间”里。
 *  2. 它不会立即把所有返回数据都复制到一块新的内存里。
 *      相反，它只用 mload 从草稿空间里加载它关心的那一部分数据来做判断（比如，检查返回值是不是true）。
 *  3. 只有在极少数情况下（比如调用失败且需要冒泡错误信息时），它才会使用 returndatacopy 把完整的返回数据复制出来。
 * 
 *  这种做法避免了在绝大多数成功调用的情况下进行不必要的内存分配，从而节省了 Gas。
 */
library SafeERC20 {
    /**
     * @dev 与 ERC-20 代币相关的操作失败。
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev 表示一个失败的 `decreaseAllowance` 请求。
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev 从调用合约向 `to` 转移 `value` 数量的 `token`。如果 `token` 不返回值，
     * 那么没有 revert 的调用将被视为成功。
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        if (!_safeTransfer(token, to, value, true)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev 从 `from` 向 `to` 转移 `value` 数量的 `token`，这会花费 `from` 授予调用合约的授权额度。
     * 如果 `token` 不返回值，那么没有 revert 的调用将被视为成功。
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        if (!_safeTransferFrom(token, from, to, value, true)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev {safeTransfer} 的变体，如果操作不成功，它会返回一个布尔值而不是 revert。
     */
    function trySafeTransfer(IERC20 token, address to, uint256 value) internal returns (bool) {
        return _safeTransfer(token, to, value, false);
    }

    /**
     * @dev {safeTransferFrom} 的变体，如果操作不成功，它会返回一个布尔值而不是 revert。
     */
    function trySafeTransferFrom(IERC20 token, address from, address to, uint256 value) internal returns (bool) {
        return _safeTransferFrom(token, from, to, value, false);
    }

    /**
     * @dev 增加调用合约对 `spender` 的授权额度，增加值为 `value`。如果 `token` 不返回值，
     * 那么没有 revert 的调用将被视为成功。
     *
     * 重要提示：如果代币实现了 ERC-7674（带临时授权的 ERC-20），并且“客户端”智能合约使用 ERC-7674 设置了临时授权，
     * 那么“客户端”智能合约应避免使用此函数。对具有非零临时授权的代币合约执行 {safeIncreaseAllowance} 或 {safeDecreaseAllowance} 
     * 操作（针对特定的 owner-spender）将导致意外行为。
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev 减少调用合约对 `spender` 的授权额度，减少值为 `requestedDecrease`。如果 `token` 不返回值，
     * 那么没有 revert 的调用将被视为成功。
     *
     * 重要提示：如果代币实现了 ERC-7674（带临时授权的 ERC-20），并且“客户端”智能合约使用 ERC-7674 设置了临时授权，
     * 那么“客户端”智能合约应避免使用此函数。对具有非零临时授权的代币合约执行 {safeIncreaseAllowance} 或 {safeDecreaseAllowance} 
     * 操作（针对特定的 owner-spender）将导致意外行为。
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev 设置调用合约对 `spender` 的授权额度为 `value`。如果 `token` 不返回值，
     * 那么没有 revert 的调用将被视为成功。此函数旨在用于那些要求在设置非零值之前必须先将授权设置为零的代币，例如 USDT。
     *
     * 注意：如果代币实现了 ERC-7674，此函数不会修改任何临时授权。此函数只设置“标准”授权。
     * 任何临时授权将保持激活状态，并与此处设置的值共存。
     * 
     * forceApprove 函数之所以设计得如此“繁琐”，是为了兼容一些早期且不规范的 ERC20 代币，其中最著名的就是 USDT (Tether)。
     * 在早期的 ERC20 代币设计中，approve 函数存在一个理论上的安全风险，被称为“approve 竞争条件”或“重放攻击”：
     * 1. 场景:
     *  小明授权给小红可以花费 100 个代币。
     *  后来，小明想把授权额度降低到 50 个，于是他发起了一笔新的交易 approve(小红, 50)。
     * 2. 攻击:
     *  小红在内存池中看到了小明这笔新的授权交易。
     *  她可以“抢跑”（Front-running），在小明的新授权生效前，立即发起一笔 transferFrom 交易，花掉全部100个代币。这笔交易是合法的，因为当前授权额度还是 100。
     *  紧接着，小明的 approve(小红, 50) 交易被打包，小红的授权额度被设置为 50。
     *  现在，小红可以再次花费 50 个代币。
     * 3. 结果: 小红总共花费了 100 + 50 = 150 个代币，远超小明任何一次的授权意图。
     * 
     * USDT 等代币的“解决方案”
     *  不允许将一个非零的授权额度直接修改为另一个非零的额度。
     * 如果你想修改授权，你必须遵循“先归零，再授权”的两步操作：
     *  1. approve(小红, 0)
     *  2. approve(小红, 50)
     * 如果你直接从 100 修改到 50，交易就会 revert。
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        // 第 1 次尝试：乐观的“标准路径”
        if (!_safeApprove(token, spender, value, false)) {
            // 如果第 1 次尝试失败，则进入“兼容模式”
            // 第 2 次尝试：设置为 0
            if (!_safeApprove(token, spender, 0, true)) revert SafeERC20FailedOperation(address(token));
            // 第 3 次尝试：再次设置为目标值
            if (!_safeApprove(token, spender, value, true)) revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev 执行一个 {ERC1363} 的 transferAndCall，如果目标地址没有代码，则回退到简单的 {ERC20} transfer。
     * 这可以用来实现类似 {ERC721} 的安全转移，当目标是合约时依赖 {ERC1363} 的检查。
     *
     * 如果返回值不为 `true`，则 revert。
     */
    function transferAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            // 非合约地址，直接使用普通的 transfer
            safeTransfer(token, to, value);
        } else if (!token.transferAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev 执行一个 {ERC1363} 的 transferFromAndCall，如果目标地址没有代码，则回退到简单的 {ERC20} transferFrom。
     * 这可以用来实现类似 {ERC721} 的安全转移，当目标是合约时依赖 {ERC1363} 的检查。
     *
     * 如果返回值不为 `true`，则 revert。
     */
    function transferFromAndCallRelaxed(
        IERC1363 token,
        address from,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        if (to.code.length == 0) {
            // 非合约地址，直接使用普通的 transferFrom
            safeTransferFrom(token, from, to, value);
        } else if (!token.transferFromAndCall(from, to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev 执行一个 {ERC1363} 的 approveAndCall，如果目标地址没有代码，则回退到简单的 {ERC20} approve。
     * 这可以用来实现类似 {ERC721} 的安全转移，当目标是合约时依赖 {ERC1363} 的检查。
     *
     * 注意：当接收地址（`to`）没有代码时（即为 EOA），此函数的行为与 {forceApprove} 相同。
     * 相反，当接收地址有代码时，此函数仅尝试调用一次 {ERC1363-approveAndCall} 而不重试，并依赖其返回值为 true。
     *
     * 如果返回值不为 `true`，则 revert。
     */
    function approveAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            // 非合约地址，直接使用普通的 approve
            forceApprove(token, to, value);
        } else if (!token.approveAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev 模拟 Solidity 的 `token.transfer(to, value)` 调用，但放宽了对返回值的要求：
     * 返回值是可选的（但如果返回了数据，则其值不能为 false）。
     *
     * @param token 调用的目标代币。
     * @param to 代币的接收者。
     * @param value 要转移的代币数量。
     * @param bubble 如果转移调用 revert 时的行为开关：是冒泡 revert 原因还是返回 false 布尔值。
     */
    function _safeTransfer(IERC20 token, address to, uint256 value, bool bubble) private returns (bool success) {
        bytes4 selector = IERC20.transfer.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(to, shr(96, not(0))))
            mstore(0x24, value)
            success := call(gas(), token, 0, 0, 0x44, 0, 0x20)
            // 如果调用成功且返回值为 true，则一切正常。
            // 否则（调用不成功或返回值不为 true），我们需要执行进一步的检查
            if iszero(and(success, eq(mload(0x00), 1))) {
                // 如果调用失败且 bubble 已启用，则冒泡该错误
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0, returndatasize())
                    revert(fmp, returndatasize())
                }
                // 如果返回值不为 true，那么只有在以下情况下调用才算成功：
                // - 代币地址有代码
                // - 返回数据为空
                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
        }
    }

    /**
     * @dev 模拟 Solidity 的 `token.transferFrom(from, to, value)` 调用，但放宽了对返回值的要求：
     * 返回值是可选的（但如果返回了数据，则其值不能为 false）。
     *
     * @param token 调用的目标代币。
     * @param from 代币的发送者。
     * @param to 代币的接收者。
     * @param value 要转移的代币数量。
     * @param bubble 如果转移调用 revert 时的行为开关：是冒泡 revert 原因还是返回 false 布尔值。
     */
    function _safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value,
        bool bubble
    ) private returns (bool success) {
        bytes4 selector = IERC20.transferFrom.selector;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(0x00, selector)
            mstore(0x04, and(from, shr(96, not(0))))
            mstore(0x24, and(to, shr(96, not(0))))
            mstore(0x44, value)
            success := call(gas(), token, 0, 0, 0x64, 0, 0x20)
            // 如果调用成功且返回值为 true，则一切正常。
            // 否则（调用不成功或返回值不为 true），我们需要执行进一步的检查
            if iszero(and(success, eq(mload(0x00), 1))) {
                // 如果调用失败且 bubble 已启用，则冒泡该错误
                if and(iszero(success), bubble) {
                    returndatacopy(fmp, 0, returndatasize())
                    revert(fmp, returndatasize())
                }
                // 如果返回值不为 true，那么只有在以下情况下调用才算成功：
                // - 代币地址有代码
                // - 返回数据为空
                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            mstore(0x40, fmp)
            // 在 Solidity 中，内存的前 128 字节（地址 0x00 到 0x7F）有特殊的预留用途：
            // 0x00 - 0x3F (64字节): 临时草稿空间 (Scratch Space)。主要用于在函数执行期间进行一些临时的计算，比如计算哈希值。
            // 0x40 - 0x5F (32字节): 空闲内存指针 (Free Memory Pointer)。它指向下一个可以被安全分配的内存地址。
            // 0x60 - 0x7F (32字节): 零槽 (Zero Slot)。按照惯例，这个内存槽在函数执行结束后应该保持为零。一些复杂的或底层的操作可能会依赖于这个槽是干净的（值为0）。
            // 因为 _safeTransferFrom 函数在执行过程中“弄脏”了本应保持为零的 0x60 内存槽，所以它有责任在函数结束前，把它清理干净，恢复为零。
            mstore(0x60, 0)
        }
    }

    /**
     * @dev 模拟 Solidity 的 `token.approve(spender, value)` 调用，但放宽了对返回值的要求：
     * 返回值是可选的（但如果返回了数据，则其值不能为 false）。
     *
     * @param token 调用的目标代币。
     * @param spender 代币的花费者。
     * @param value 要转移的代币数量。
     * @param bubble 如果转移调用 revert 时的行为开关：是冒泡 revert 原因还是返回 false 布尔值。
     */
    function _safeApprove(IERC20 token, address spender, uint256 value, bool bubble) private returns (bool success) {
        bytes4 selector = IERC20.approve.selector;

        assembly ("memory-safe") {
            // 获取当前“空闲内存指针”的位置，并存入变量 fmp。
            let fmp := mload(0x40)
            // 将 approve 函数的选择器（4字节）存入内存的 0x00 位置。
            // 这是我们手动构建的 calldata 的第一部分。
            // 注意：这里使用的是一个临时的、从0x00开始的内存“草稿区”，而不是 fmp 指向的位置。
            mstore(0x00, selector)
            // mstore(0x04, and(spender, shr(96, not(0))))
            // 将第一个参数 spender (地址，20字节) 存入内存的 0x04 位置。
            // 地址需要被正确地格式化为32字节的槽，这段汇编就是为了完成这个格式化。
            mstore(0x04, and(spender, shr(96, not(0))))
            // 将第二个参数 value (uint256，32字节) 存入内存的 0x24 位置 (0x04 + 32字节 = 0x24)。
            mstore(0x24, value)
            // 到此，我们在内存的 0x00 到 0x44 (总计68字节) 的区域里，
            // 手动拼装了调用 `approve(address, uint256)` 所需的 calldata。
            // [4字节 selector][32字节 spender][32字节 value]    
            // 这是最核心的一步：执行底层的 call 调用。
            // 参数分解:
            // - gas():   提供所有剩余的 gas
            // - token:   调用的目标合约地址
            // - 0:       不发送任何 ETH
            // - 0:       输入数据（calldata）的起始内存地址 (我们刚刚构建的 0x00)
            // - 0x44:    输入数据的大小 (68字节)
            // - 0:       输出数据（returndata）的存放起始内存地址 (直接覆盖我们用过的草稿区)
            // - 0x20:    期望的输出数据的最大大小 (32字节，因为 bool 值占一个槽)
            // `call` 的返回值 (0代表失败/revert, 1代表成功) 被存入 `success` 变量。

            // success只代表有没有调用成功，并不代表调用的结果（返回值）是什么。 --
            //   success 的值为 0 (false),意味着对方合约的函数在执行过程中被 `revert` 了。
            //      revert 的原因（例如，require 语句中的错误信息）会被存放在一个叫做 returndata
            //      的缓冲区里，这就是为什么后续的汇编代码可以把这个错误原因“冒泡”上来。
            //   success 为 1 的情况下，可能发生了以下任何一种情况： 
            //      理想情况: approve 函数执行了，并且按标准返回了 true。
            //      逻辑失败: approve 函数执行了，但由于某种原因（如不满足条件），它按标准返回了 false。
            //      不规范但成功: approve 函数执行了，并且没有返回任何值 (void)，比如 USDT 的 approve。
            //      意外情况: 你调用的函数根本不存在，但对方合约有一个 fallback 函数，并且这个 fallback 函数成功执行完毕了。
            // `success` 为 `1` 只能告诉我们：“对方没有 `revert`”。需要结合返回值才能确认是否返回了 `true`。
            success := call(gas(), token, 0, 0, 0x44, 0, 0x20)
            // 如果调用成功且返回值为 true，则一切正常。
            // 否则（调用不成功或返回值不为 true），我们需要执行进一步的检查
            // 这是一个“如果情况不完美”的检查。我们来拆解这个条件：
            // - mload(0x00): 从内存0x00处加载返回的数据（因为我们让它写回到了这个位置）。
            // - eq(..., 1):   判断返回数据是否等于 1 (即 true)。
            // - and(success, ...): 判断是否 (调用成功 AND 返回值为 true)。这是最理想的“完美情况”。
            // - iszero(...):   对“完美情况”取反。
            // 所以，如果 (调用失败了) 或者 (返回值不为 true)，!(success==1 && true) 就会进入这个 if 语句块。
            if iszero(and(success, eq(mload(0x00), 1))) {
                // 如果调用失败且 bubble 已启用，则冒泡该错误
                // if and(iszero(success), bubble)
                // 如果进入了“不完美”的情况，首先检查是不是因为调用本身就 revert 了 (success == 0)。
                // 如果是，并且 bubble 参数为 true，那么就把对方合约的 revert 原因原封不动地“冒泡”出去。
                if and(iszero(success), bubble) {   //
                    returndatacopy(fmp, 0, returndatasize())
                    revert(fmp, returndatasize())
                }
                // 如果返回值不为 true，那么只有在以下情况下调用才算成功：
                // 这是处理 void 返回类型代币的关键！
                // 它重新定义了“成功”：一个不完美的调用，仍然可以被认为是成功的，只要同时满足以下三个条件：
                // 1. `success`: 原始的 call 调用没有 revert。
                // 2. `iszero(returndatasize())`: 对方合约没有返回任何数据 (即 void 函数)。
                // 3. `gt(extcodesize(token), 0)`: 目标地址确实是一个合约。
                // 只有这三个条件都满足，才会把 `success` 变量最终设置为 true。
                success := and(success, and(iszero(returndatasize()), gt(extcodesize(token), 0)))
            }
            // 将空闲内存指针恢复到它在函数开始时的位置。这是一个良好的编程习惯。
            mstore(0x40, fmp)
        }
    }
}
