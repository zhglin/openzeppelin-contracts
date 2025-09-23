// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/draft-IERC7821.sol)

pragma solidity >=0.5.0;

/**
 * @dev 最小化批量执行器的接口。
 */
interface IERC7821 {
    /**
     * @dev 在 `executionData` 中执行调用。
     * 如果任何调用失败，则回滚并冒泡错误。
     *
     * `executionData` 编码:
     * - 如果 `opData` 为空，`executionData` 就是 `abi.encode(calls)`。
     * - 否则，`executionData` 是 `abi.encode(calls, opData)`。
     *   参见: https://eips.ethereum.org/EIPS/eip-7579
     *
     * 支持的模式:
     * - `bytes32(0x01000000000000000000...)`: 不支持可选的 `opData`。
     * - `bytes32(0x01000000000078210001...)`: 支持可选的 `opData`。
     *
     * 授权检查:
     * - 如果 `opData` 为空，实现 SHOULD 要求
     *   `msg.sender == address(this)`。
     * - 如果 `opData` 不为空，实现 SHOULD 使用
     *   `opData` 中编码的签名来确定调用者是否可以执行。
     *
     * `opData` 可用于存储额外的认证数据、paymaster 数据、gas 限制等。
     *
     * 为了 calldata 压缩效率，如果一个 Call.to 是 `address(0)`，
     * 它将被替换为 `address(this)`。
     */
    function execute(bytes32 mode, bytes calldata executionData) external payable;

    /**
     * @dev 提供此函数供前端检测支持情况。
     * 仅在以下情况下返回 true:
     * - `bytes32(0x01000000000000000000...)`: 不支持可选的 `opData`。
     * - `bytes32(0x01000000000078210001...)`: 支持可选的 `opData`。
     */
    function supportsExecutionMode(bytes32 mode) external view returns (bool);
}
