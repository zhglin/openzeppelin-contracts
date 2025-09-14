// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (最后更新于 v5.3.0) (utils/Multicall.sol)

pragma solidity ^0.8.20;

import {Address} from "./Address.sol";
import {Context} from "./Context.sol";

/**
 * @dev 提供一个函数，用于在单次外部调用中批量处理多个调用。
 *
 * 请注意，如果发送者在发送调用 {multicall} 的交易时不特别小心，
 * 那么关于发送者执行的 calldata 验证的任何假设都可能被违反。
 * 例如，一个过滤函数选择器的中继地址不会过滤嵌套在 {multicall} 操作中的调用。
 *
 * 注意：自 5.0.1 和 4.9.4 版本起，此合约会识别非规范上下文（即 `msg.sender` 不是 {Context-_msgSender}）。
 * 如果识别出非规范上下文，接下来的自身 `delegatecall` 会将 `msg.data` 的最后一些字节附加到子调用中。
 * 这使得它可以安全地与 {ERC2771Context} 一起使用。不影响 {Context-_msgSender} 解析的上下文不会传播到子调用中。
 */
abstract contract Multicall is Context {
    /**
     * @dev 在此合约上接收并执行一批函数调用。
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function multicall(bytes[] calldata data) external virtual returns (bytes[] memory results) {
        bytes memory context = msg.sender == _msgSender()
            ? new bytes(0)
            : msg.data[msg.data.length - _contextSuffixLength():];

        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            results[i] = Address.functionDelegateCall(address(this), bytes.concat(data[i], context));
        }
        return results;
    }
}
