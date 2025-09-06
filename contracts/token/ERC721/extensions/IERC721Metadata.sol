// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity >=0.6.2;

import {IERC721} from "../IERC721.sol";

/**
 * @title ERC-721 不可替代代币标准，可选的元数据扩展
 * @dev 参见 https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev 返回代币集合的名称。
     */
    function name() external view returns (string memory);

    /**
     * @dev 返回代币集合的符号。
     */
    function symbol() external view returns (string memory);

    /**
     * @dev 返回 `tokenId` 代币的统一资源标识符 (URI)。
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
