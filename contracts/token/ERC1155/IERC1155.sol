// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.4.0) (token/ERC1155/IERC1155.sol)

pragma solidity >=0.6.2;

import {IERC165} from "../../utils/introspection/IERC165.sol";

/**
 * @dev 符合 ERC-1155 标准的合约所需接口，定义于
 * https://eips.ethereum.org/EIPS/eip-1155[ERC]。
 */
interface IERC1155 is IERC165 {
    /**
     * @dev 当 `operator` 将 `value` 数量的 `id` 类型代币从 `from` 转移到 `to` 时发出。
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev 相当于多个 {TransferSingle} 事件，其中所有转移的 `operator`、`from` 和 `to` 都相同。
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    /**
     * @dev 当 `account` 根据 `approved` 授予或撤销 `operator` 转移其代币的权限时发出。
     */
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /**
     * @dev 当 `id` 类型代币的 URI 更改为 `value` 时发出，如果它是一个非程序化 URI。
     *
     * 如果为 `id` 发出了一个 {URI} 事件，标准
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[保证] `value` 将等于
     * {IERC1155MetadataURI-uri} 返回的值。
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev 返回 `account` 拥有的 `id` 类型代币的数量。
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[批处理] 版本的 {balanceOf}。
     * 要求：
     * - `accounts` 和 `ids` 必须具有相同的长度。
     */
    function balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata ids
    ) external view returns (uint256[] memory);

    /**
     * @dev 根据 `approved` 授予或撤销 `operator` 转移调用者代币的权限。
     * 发出 {ApprovalForAll} 事件。
     * 要求：
     * - `operator` 不能是零地址。
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev 如果 `operator` 被批准转移 `account` 的代币，则返回 true。
     * 参见 {setApprovalForAll}。
     */
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /**
     * @dev 将 `value` 数量的 `id` 类型代币从 `from` 转移到 `to`。
     *
     * 警告：当将代币转移到不受信任的合约时，在接收者上调用 {IERC1155Receiver-onERC1155Received} 时，
     * 此函数可能允许重入攻击。
     * 在与不受信任的合约交互时，请确保遵循检查-效果-交互模式，并考虑使用重入守卫。
     * 发出 {TransferSingle} 事件。
     *
     * 要求：
     * - `to` 不能是零地址。
     * - 如果调用者不是 `from`，则必须已通过 {setApprovalForAll} 被批准花费 `from` 的代币。
     * - `from` 必须拥有至少 `value` 数量的 `id` 类型代币的余额。
     * - 如果 `to` 指的是一个智能合约，它必须实现 {IERC1155Receiver-onERC1155Received} 并返回接受魔法值。
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes calldata data) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[批处理] 版本的 {safeTransferFrom}。
     *
     * 警告：当将代币转移到不受信任的合约时，在接收者上调用 {IERC1155Receiver-onERC1155BatchReceived} 时，
     * 此函数可能允许重入攻击。
     * 在与不受信任的合约交互时，请确保遵循检查-效果-交互模式，并考虑使用重入守卫。
     * 根据数组参数的长度，发出 {TransferSingle} 或 {TransferBatch} 事件。
     *
     * 要求：
     * - `ids` 和 `values` 必须具有相同的长度。
     * - 如果 `to` 指的是一个智能合约，它必须实现 {IERC1155Receiver-onERC1155BatchReceived} 并返回接受魔法值。
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external;
}
