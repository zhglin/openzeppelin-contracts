// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity >=0.4.16;

/**
 * @dev ERC-20 Permit 扩展接口，允许通过签名进行授权，定义在
 * https://eips.ethereum.org/EIPS/eip-2612[ERC-2612] 中。
 *
 * 添加了 {permit} 方法，该方法可以通过提供账户签名的消息来更改账户的 ERC-20 授权（参见 {IERC20-allowance}）。
 * 通过不依赖 {IERC20-approve}，代币持有者账户无需发送交易，因此完全不需要持有 Ether。
 *
 * ==== 安全注意事项
 *
 * 关于 `permit` 的使用有两个重要的考虑事项。首先，有效的 permit 签名表示一种授权，不应假定它传达了额外的含义。
 * 特别是，不应将其视为以任何特定方式花费授权的意图。其次，由于 permit 具有内置的重放保护，并且可以由任何人提交，
 * 因此它们可能会被抢跑。使用 permit 的协议应考虑到这一点，并允许 `permit` 调用失败。结合这两个方面，
 * 通常推荐的模式是：
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * 请注意：1) `msg.sender` 用作所有者，对签名者的意图没有歧义，2) 使用 `try/catch` 允许 permit 失败，
 * 并使代码能够容忍抢跑。（另请参见 {SafeERC20-safeTransferFrom}）。
 *
 * 此外，请注意智能合约钱包（如 Argent 或 Safe）无法生成 permit 签名，因此合约应具有不依赖 permit 的入口点。
 */
interface IERC20Permit {
    /**
     * @dev 根据 `owner` 的签名批准，将 `value` 设置为 `spender` 对 `owner` 代币的授权。
     *
     * 重要提示：{IERC20-approve} 中与交易排序相关的问题也适用于此处。
     *
     * 发出 {Approval} 事件。
     *
     * 要求：
     *
     * - `spender` 不能是零地址。
     * - `deadline` 必须是未来的时间戳。
     * - `v`、`r` 和 `s` 必须是 `owner` 对 EIP712 格式化函数参数的有效 `secp256k1` 签名。
     * - 签名必须使用 `owner` 的当前 nonce（参见 {nonces}）。
     *
     * 有关签名格式的更多信息，请参阅
     * https://eips.ethereum.org/EIPS/eip-2612#specification[相关 EIP 部分]。
     *
     * 注意：请参阅上面的安全注意事项。
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev 返回 `owner` 的当前 nonce。每当为 {permit} 生成签名时，必须包含此值。
     *
     * 每次成功调用 {permit} 都会使 `owner` 的 nonce 增加一。这可以防止签名被多次使用。
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev 返回用于 {permit} 签名编码的域分隔符，由 {EIP712} 定义。
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
