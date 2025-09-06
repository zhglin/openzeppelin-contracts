// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.4.0) (token/ERC1155/IERC1155Receiver.sol)

pragma solidity >=0.6.2;

import {IERC165} from "../../utils/introspection/IERC165.sol";

/**
 * @dev 为了接收 ERC-1155 代币转移，智能合约必须实现的接口。
 */
interface IERC1155Receiver is IERC165 {
    /**
     * @dev 处理接收单一类型的 ERC-1155 代币。此函数在 `safeTransferFrom`
     * 的末尾，在余额更新后被调用。
     *
     * 注意：要接受转移，此函数必须返回
     * `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     * (即 0xf23a6e61，或其自身的函数选择器)。
     *
     * @param operator 发起转移的地址 (即 msg.sender)
     * @param from 先前拥有代币的地址
     * @param id 正在转移的代币的 ID
     * @param value 正在转移的代币数量
     * @param data 无特定格式的附加数据
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` 如果允许转移
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
     * @dev 处理接收多种类型的 ERC-1155 代币。此函数在 `safeBatchTransferFrom`
     * 的末尾，在余额更新后被调用。
     *
     * 注意：要接受转移，此函数必须返回
     * `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     * (即 0xbc197c81, 或其自身的函数选择器)。
     *
     * @param operator 发起批量转移的地址 (即 msg.sender)
     * @param from 先前拥有代币的地址
     * @param ids 包含每个正在转移的代币 ID 的数组 (顺序和长度必须与 values 数组匹配)
     * @param values 包含每个正在转移的代币数量的数组 (顺序和长度必须与 ids 数组匹配)
     * @param data 无特定格式的附加数据
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` 如果允许转移
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}
