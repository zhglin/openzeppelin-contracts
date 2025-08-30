// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/utils/ERC1363Utils.sol)

pragma solidity ^0.8.20;

import {IERC1363Receiver} from "../../../interfaces/IERC1363Receiver.sol";
import {IERC1363Spender} from "../../../interfaces/IERC1363Spender.sol";

/**
 * @dev 提供通用 ERC-1363 实用函数的库。
 *
 * 参见 https://eips.ethereum.org/EIPS/eip-1363[ERC-1363]。
 * 
 * 为什么要求IERC1363Receiver.onTransferReceived和IERC1363Spender.onApprovalReceived必须返回函数选择器？
 *      这个要求将一个隐式的约定（“你应该有一个这样签名的函数”）变成了一个显式的确认（“我确认我收到了回调，并且我知道我需要遵守 ERC1363 协议”）。
 *       一个合约会与 onTransferReceived 偶然“撞名”的概率虽然低，但不是零。
 *      但是，一个偶然撞名的函数，内部恰好还包含了 return this.onTransferReceived.selector; 这句代码的概率，几乎为零。
 * 
 * 在 Solidity 中，当出现错误或不满足条件时，标准的处理方式是调用 revert()、require() 或 error()。这些操作会：
 *      1. 立即停止当前函数以及整个交易的执行。
 *      2. 回滚这笔交易中已经发生的所有状态变更（比如修改的变量、转出的代币等），就像这笔交易从未发生过一样。
 *      3. 不会有任何返回值。因为函数在中间就被中止了，根本走不到 return 那一步。
 */
library ERC1363Utils {
    /**
     * @dev 表示代币 `receiver`（接收方）出现故障。在转账中使用。
     * @param receiver 正在接收代币的地址。
     */
    error ERC1363InvalidReceiver(address receiver);

    /**
     * @dev 表示代币 `spender`（花费方）出现故障。在授权中使用。
     * @param spender 可能被允许在非所有者的情况下操作代币的地址。
     */
    error ERC1363InvalidSpender(address spender);

    /**
     * @dev 在目标地址上执行对 {IERC1363Receiver-onTransferReceived} 的调用。
     *
     * 要求：
     * - 目标地址有代码（即它是一个合约）。
     * - 目标地址 `to` 必须实现 {IERC1363Receiver} 接口。
     * - 目标必须返回 {IERC1363Receiver-onTransferReceived} 的函数选择器以接受转账。
     */
    function checkOnERC1363TransferReceived(
        address operator,
        address from,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        if (to.code.length == 0) {
            revert ERC1363InvalidReceiver(to);
        }

        try IERC1363Receiver(to).onTransferReceived(operator, from, value, data) returns (bytes4 retval) {
            if (retval != IERC1363Receiver.onTransferReceived.selector) {
                revert ERC1363InvalidReceiver(to);
            }
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert ERC1363InvalidReceiver(to);
            } else {
                assembly ("memory-safe") {
                    revert(add(reason, 0x20), mload(reason))
                }
            }
        }
    }

    /**
     * @dev 在目标地址上执行对 {IERC1363Spender-onApprovalReceived} 的调用。
     *
     * 要求：
     * - 目标地址有代码（即它是一个合约）。
     * - 目标地址 `spender` 必须实现 {IERC1363Spender} 接口。
     * - 目标必须返回 {IERC1363Spender-onApprovalReceived} 的函数选择器以接受授权。
     */
    function checkOnERC1363ApprovalReceived(
        address operator,
        address spender,
        uint256 value,
        bytes memory data
    ) internal {
        if (spender.code.length == 0) {
            revert ERC1363InvalidSpender(spender);
        }

        try IERC1363Spender(spender).onApprovalReceived(operator, value, data) returns (bytes4 retval) {
            if (retval != IERC1363Spender.onApprovalReceived.selector) {
                revert ERC1363InvalidSpender(spender);
            }
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert ERC1363InvalidSpender(spender);
            } else {
                assembly ("memory-safe") {
                    revert(add(reason, 0x20), mload(reason))
                }
            }
        }
    }
}
