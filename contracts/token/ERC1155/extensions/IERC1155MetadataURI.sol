// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.4.0) (token/ERC1155/extensions/IERC1155MetadataURI.sol)

pragma solidity >=0.6.2;

import {IERC1155} from "../IERC1155.sol";

/**
 * @dev 可选的 ERC1155MetadataExtension 接口，定义于
 * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[ERC]。
 */
interface IERC1155MetadataURI is IERC1155 {
    /**
     * @dev 返回 `id` 类型代币的 URI。
     * 如果 URI 中存在 `\{id\}` 子字符串，客户端必须将其替换为实际的代币类型 ID。
     */
    function uri(uint256 id) external view returns (string memory);
}
