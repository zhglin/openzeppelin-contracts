// SPDX-License-Identifier: MIT
// OpenZeppelin 合约 (最后更新于 v5.1.0) (token/ERC1155/extensions/ERC1155URIStorage.sol)

pragma solidity ^0.8.24;

import {Strings} from "../../../utils/Strings.sol";
import {ERC1155} from "../ERC1155.sol";

/**
 * @dev 具有基于存储的代币 URI 管理功能的 ERC-1155 代币。
 * 灵感来自于 {ERC721URIStorage} 扩展
 */
abstract contract ERC1155URIStorage is ERC1155 {
    using Strings for uint256;

    // 可选的基础 URI
    string private _baseURI = "";

    // 可选的代币 URI 映射
    mapping(uint256 tokenId => string) private _tokenURIs;

    /**
     * @dev 参见 {IERC1155MetadataURI-uri}。
     *
     * 如果设置了特定于代币的 uri，此实现将返回 `_baseURI`和该 uri 的串联。
     *
     * 这启用了以下行为：
     * - 如果设置了 `_tokenURIs[tokenId]`，则结果是`_baseURI` 和 `_tokenURIs[tokenId]` 的串联（请记住，`_baseURI`默认为空）；
     * - 如果未设置 `_tokenURIs[tokenId]`，则我们回退到 `super.uri()`，在大多数情况下，它将包含 `ERC1155._uri`；
     * - 如果未设置 `_tokenURIs[tokenId]`，并且父级没有设置uri 值，则结果为空。
     */
    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        string memory tokenURI = _tokenURIs[tokenId];

        // 如果设置了代币 URI，则连接基础 URI 和代币 URI（通过 string.concat）。
        return bytes(tokenURI).length > 0 ? string.concat(_baseURI, tokenURI) : super.uri(tokenId);
    }

    /**
     * @dev 将 `tokenURI` 设置为 `tokenId` 的 tokenURI。
     */
    function _setURI(uint256 tokenId, string memory tokenURI) internal virtual {
        _tokenURIs[tokenId] = tokenURI;
        emit URI(uri(tokenId), tokenId);
    }

    /**
     * @dev 将 `baseURI` 设置为所有代币的 `_baseURI`。
     */
    function _setBaseURI(string memory baseURI) internal virtual {
        _baseURI = baseURI;
    }
}
