// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC721/IERC721.sol)

pragma solidity >=0.6.2;

import {IERC165} from "../../utils/introspection/IERC165.sol";

/**
 * @dev 符合 ERC-721 标准的合约所需的接口。
 */
interface IERC721 is IERC165 {
    /**
     * @dev 当 `tokenId` 代币从 `from` 转移到 `to` 时发出。
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev 当 `owner` 授权 `approved` 管理 `tokenId` 代币时发出。
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev 当 `owner` 启用或禁用 (`approved`) `operator` 管理其所有资产时发出。
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev 返回 `owner` 账户中的代币数量。
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev 返回 `tokenId` 代币的所有者。
     * 要求：
     * - `tokenId` 必须存在。
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev 安全地将 `tokenId` 代币从 `from` 转移到 `to`。
     * 要求：
     * - `from` 不能是零地址。
     * - `to` 不能是零地址。
     * - `tokenId` 代币必须存在且由 `from` 拥有。
     * - 如果调用者不是 `from`，则必须通过 {approve} 或 {setApprovalForAll} 授权其转移此代币。
     * - 如果 `to` 指向一个智能合约，则它必须实现 {IERC721Receiver-onERC721Received}，该函数在安全转移时被调用。
     * 发出 {Transfer} 事件。
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev 安全地将 `tokenId` 代币从 `from` 转移到 `to`，首先检查合约接收者是否了解 ERC-721 协议，以防止代币被永久锁定。
     * 要求：
     * - `from` 不能是零地址。
     * - `to` 不能是零地址。
     * - `tokenId` 代币必须存在且由 `from` 拥有。
     * - 如果调用者不是 `from`，则必须通过 {approve} 或 {setApprovalForAll} 授权其转移此代币。
     * - 如果 `to` 指向一个智能合约，则它必须实现 {IERC721Receiver-onERC721Received}，该函数在安全转移时被调用。
     * 发出 {Transfer} 事件。
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev 将 `tokenId` 代币从 `from` 转移到 `to`。
     * 警告：请注意，调用者有责任确认接收者能够接收 ERC-721 代币，否则它们可能会永久丢失。使用 {safeTransferFrom} 可以防止丢失，但调用者必须了解这会增加一个外部调用，从而可能产生重入漏洞。
     * 要求：
     * - `from` 不能是零地址。
     * - `to` 不能是零地址。
     * - `tokenId` 代币必须由 `from` 拥有。
     * - 如果调用者不是 `from`，则必须通过 {approve} 或 {setApprovalForAll} 授权其转移此代币。
     * 发出 {Transfer} 事件。
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev 授权 `to` 将 `tokenId` 代币转移到另一个账户。
     * 当代币被转移时，授权被清除。
     * 一次只能授权一个账户，因此授权零地址会清除以前的授权。
     * 要求：
     * - 调用者必须拥有代币或者是授权的操作员。
     * - `tokenId` 必须存在。
     * 发出 {Approval} 事件。
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev 为调用者批准或移除 `operator` 作为操作员。
     * 操作员可以为调用者拥有的任何代币调用 {transferFrom} 或 {safeTransferFrom}。
     * 要求：
     * - `operator` 不能是零地址。
     * 发出 {ApprovalForAll} 事件。
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev 返回 `tokenId` 代币的授权账户。
     * 要求：
     * - `tokenId` 必须存在。
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev 返回 `operator` 是否被允许管理 `owner` 的所有资产。
     * 参见 {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}
