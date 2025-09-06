// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.4.0) (interfaces/draft-IERC6093.sol)

pragma solidity >=0.8.4;

/**
 * @dev 标准 ERC-20 错误
 * https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] 为 ERC-20 代币定义的自定义错误的接口。
 */
interface IERC20Errors {
    /**
     * @dev 表示与 `sender` 的当前 `balance` 相关的错误。在转移中使用。
     * @param sender 正在转移其代币的地址。
     * @param balance 交互账户的当前余额。
     * @param needed 执行转移所需的最小金额。
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev 表示代币 `sender` 的失败。在转移中使用。
     * @param sender 正在转移其代币的地址。
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev 表示代币 `receiver` 的失败。在转移中使用。
     * @param receiver 正在接收代币的地址。
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev 表示 `spender` 的 `allowance` 的失败。在转移中使用。
     * @param spender 可能被允许在不是其所有者的情况下操作代币的地址。
     * @param allowance `spender` 被允许操作的代币数量。
     * @param needed 执行转移所需的最小金额。
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev 表示待批准代币的 `approver` 的失败。在批准中使用。
     * @param approver 发起批准操作的地址。
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev 表示待批准的 `spender` 的失败。在批准中使用。
     * @param spender 可能被允许在不是其所有者的情况下操作代币的地址。
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev 标准 ERC-721 错误
 * https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] 为 ERC-721 代币定义的自定义错误的接口。
 */
interface IERC721Errors {
    /**
     * @dev 表示一个地址不能成为所有者。例如，`address(0)` 在 ERC-20 中是禁止的所有者。
     * 在余额查询中使用。
     * @param owner 代币当前所有者的地址。
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev 表示一个 `tokenId` 的 `owner` 是零地址。
     * @param tokenId 代币的标识符编号。
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev 表示与特定代币的所有权相关的错误。在转移中使用。
     * @param sender 正在转移其代币的地址。
     * @param tokenId 代币的标识符编号。
     * @param owner 代币当前所有者的地址。
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev 表示代币 `sender` 的失败。在转移中使用。
     * @param sender 正在转移其代币的地址。
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev 表示代币 `receiver` 的失败。在转移中使用。
     * @param receiver 正在接收代币的地址。
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev 表示 `operator` 的批准失败。在转移中使用。
     * @param operator 可能被允许在不是其所有者的情况下操作代币的地址。
     * @param tokenId 代币的标识符编号。
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev 表示待批准代币的 `approver` 的失败。在批准中使用。
     * @param approver 发起批准操作的地址。
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev 表示待批准的 `operator` 的失败。在批准中使用。
     * @param operator 可能被允许在不是其所有者的情况下操作代币的地址。
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev 标准 ERC-1155 错误
 * https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] 为 ERC-1155 代币定义的自定义错误的接口。
 */
interface IERC1155Errors {
    /**
     * @dev 表示与 `sender` 的当前 `balance` 相关的错误。在转移中使用。
     * @param sender 正在转移其代币的地址。
     * @param balance 交互账户的当前余额。
     * @param needed 执行转移所需的最小金额。
     * @param tokenId 代币的标识符编号。
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev 表示代币 `sender` 的失败。在转移中使用。
     * @param sender 正在转移其代币的地址。
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev 表示代币 `receiver` 的失败。在转移中使用。
     * @param receiver 正在接收代币的地址。
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev 表示 `operator` 的批准失败。在转移中使用。
     * @param operator 可能被允许在不是其所有者的情况下操作代币的地址。
     * @param owner 代币当前所有者的地址。
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev 表示待批准代币的 `approver` 的失败。在批准中使用。
     * @param approver 发起批准操作的地址。
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev 表示待批准的 `operator` 的失败。在批准中使用。
     * @param operator 可能被允许在不是其所有者的情况下操作代币的地址。
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev 表示在 safeBatchTransferFrom 操作中 ids 和 values 之间的数组长度不匹配。
     * 在批量转移中使用。
     * @param idsLength 代币标识符数组的长度
     * @param valuesLength 代币数量数组的长度
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}
