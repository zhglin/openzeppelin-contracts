// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC1363.sol)

pragma solidity >=0.6.2;

import {IERC20} from "./IERC20.sol";
import {IERC165} from "./IERC165.sol";

/**
 * @title IERC1363
 * @dev ERC-1363 标准的接口，定义于 https://eips.ethereum.org/EIPS/eip-1363[ERC-1363]。
 *
 * 为 ERC-20 代币定义了一个扩展接口，支持在 `transfer` 或 `transferFrom` 之后，在接收方合约上执行代码；
 * 或在 `approve` 之后，在花费方合约上执行代码，所有操作均在单笔交易中完成。
 */
interface IERC1363 is IERC20, IERC165 {
    /*
     * 注意：此接口的 ERC-165 标识符是 0xb0202a11。
     * 0xb0202a11 ===
     *   bytes4(keccak256('transferAndCall(address,uint256)')) ^
     *   bytes4(keccak256('transferAndCall(address,uint256,bytes)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256,bytes)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256,bytes)'))
     */

    /**
     * @dev 将 `value` 数量的代币从调用者账户转移到 `to` 地址，
     * 然后在 `to` 地址上调用 {IERC1363Receiver-onTransferReceived}。
     * @param to 你想要转入代币的地址。
     * @param value 要转移的代币数量。
     * @return 一个布尔值，表示操作是否成功（除非抛出异常）。
     */
    function transferAndCall(address to, uint256 value) external returns (bool);

    /**
     * @dev 将 `value` 数量的代币从调用者账户转移到 `to` 地址，
     * 然后在 `to` 地址上调用 {IERC1363Receiver-onTransferReceived}。
     * @param to 你想要转入代币的地址。
     * @param value 要转移的代币数量。
     * @param data 附加数据，无特定格式，在调用 `to` 时发送。
     * @return 一个布尔值，表示操作是否成功（除非抛出异常）。
     */
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev 使用授权（allowance）机制，将 `value` 数量的代币从 `from` 地址转移到 `to` 地址，
     * 然后在 `to` 地址上调用 {IERC1363Receiver-onTransferReceived}。
     * @param from 你想要从中转出代币的地址。
     * @param to 你想要转入代币的地址。
     * @param value 要转移的代币数量。
     * @return 一个布尔值，表示操作是否成功（除非抛出异常）。
     */
    function transferFromAndCall(address from, address to, uint256 value) external returns (bool);

    /**
     * @dev 使用授权（allowance）机制，将 `value` 数量的代币从 `from` 地址转移到 `to` 地址，
     * 然后在 `to` 地址上调用 {IERC1363Receiver-onTransferReceived}。
     * @param from 你想要从中转出代币的地址。
     * @param to 你想要转入代币的地址。
     * @param value 要转移的代币数量。
     * @param data 附加数据，无特定格式，在调用 `to` 时发送。
     * @return 一个布尔值，表示操作是否成功（除非抛出异常）。
     */
    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev 将 `value` 数量的代币设置为 `spender` 对调用者代币的授权额度，
     * 然后在 `spender` 上调用 {IERC1363Spender-onApprovalReceived}。
     * @param spender 将要花费资金的地址。
     * @param value 将要花费的代币数量。
     * @return 一个布尔值，表示操作是否成功（除非抛出异常）。
     */
    function approveAndCall(address spender, uint256 value) external returns (bool);

    /**
     * @dev 将 `value` 数量的代币设置为 `spender` 对调用者代币的授权额度，
     * 然后在 `spender` 上调用 {IERC1363Spender-onApprovalReceived}。
     * @param spender 将要花费资金的地址。
     * @param value 将要花费的代币数量。
     * @param data 附加数据，无特定格式，在调用 `spender` 时发送。
     * @return 一个布尔值，表示操作是否成功（除非抛出异常）。
     */
    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
}
